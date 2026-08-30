#!/usr/bin/env bash
# Blue-green deploy for awattprice-backend v3.
#
# Starts a green API alongside the live blue stack, smoke-tests it, then
# cuts over nginx with zero dropped connections. After confirmation the blue
# stack is torn down and the server is left in the canonical compose state.
#
# Usage:
#   ./deploy-blue-green.v3.sh user@server
#
# Env-var overrides:
#   AWATTPRICE_IMAGE       canonical Docker image tag       (default awattprice-backend:v3)
#   AWATTPRICE_HOST_ROOT   config/data root on the server   (default /etc/awattprice-v3)
#   AWATTPRICE_COMPOSE_ROOT compose file root on the server  (default /srv/awattprice-v3)
#   AWATTPRICE_NOTIFICATION_BACKUP_DIR local notification profile backup directory
#                                                       (default ./backups/notification-profiles)
#   AWATTPRICE_BLUE_PORT   port blue API is currently on  (default 8003)
#   AWATTPRICE_GREEN_PORT  port green API will start on   (default 8004)
#   AWATTPRICE_NGINX_CONF  nginx site config              (default /etc/nginx/sites-enabled/awattprice)
#   AWATTPRICE_SETTLE_SECONDS seconds to wait after worker restart before final cutback (default 8)
set -euo pipefail

cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
SERVER="${1:-${AWATTPRICE_DEPLOY_TARGET:-}}"
if [ -z "$SERVER" ]; then
  echo "Usage: $0 user@server" >&2
  exit 1
fi

IMAGE="${AWATTPRICE_IMAGE:-awattprice-backend:v3}"
GREEN_IMAGE="${IMAGE}-green"
HOST_ROOT="${AWATTPRICE_HOST_ROOT:-/etc/awattprice-v3}"
COMPOSE_ROOT="${AWATTPRICE_COMPOSE_ROOT:-/srv/awattprice-v3}"
PLATFORM="${AWATTPRICE_DOCKER_PLATFORM:-}"
REMOTE_DOCKER="${AWATTPRICE_REMOTE_DOCKER:-docker}"
REMOTE_COMPOSE="${AWATTPRICE_REMOTE_COMPOSE:-docker compose}"
BLUE_PORT="${AWATTPRICE_BLUE_PORT:-8003}"
GREEN_PORT="${AWATTPRICE_GREEN_PORT:-8004}"
NGINX_CONF="${AWATTPRICE_NGINX_CONF:-/etc/nginx/sites-enabled/awattprice}"
SETTLE_SECONDS="${AWATTPRICE_SETTLE_SECONDS:-8}"
NOTIFICATION_BACKUP_DIR="${AWATTPRICE_NOTIFICATION_BACKUP_DIR:-./backups/notification-profiles}"

BLUE_API="awattprice-backend-v3"
GREEN_API="awattprice-backend-v3-green"
GREEN_NOTIFICATIONS="awattprice-notifications-v3-green"
GREEN_REFRESHER="awattprice-data-refresher-v3-green"
NOTIFICATION_PROFILE_STORE="${HOST_ROOT}/data/notification-profiles.json"

step() { echo; echo "==> $*"; }
info() { echo "    $*"; }

verify_price_statistics_contract() {
  local port="$1"
  local label="$2"
  local response

  if ! response=$(ssh "$SERVER" "curl -fsS -X POST -H 'Content-Type: application/json' --data '{\"add_ons\":[]}' 'http://127.0.0.1:${port}/prices/DE-LU/statistics'"); then
    echo "ERROR: ${label} price-statistics request failed on port ${port}." >&2
    return 1
  fi

  if ! printf '%s' "$response" | python3 -c '
import json
import sys

payload = json.load(sys.stdin)
if not isinstance(payload, dict) or not payload:
    raise SystemExit("empty statistics response")

distribution_keys = {
    "cheap_percent",
    "typical_percent",
    "expensive_percent",
    "cheap_below",
    "expensive_above",
}
for range_key, statistics in payload.items():
    distribution = statistics.get("distribution")
    pattern = statistics.get("weekday_hour_pattern")
    if not isinstance(distribution, dict) or not distribution_keys.issubset(distribution):
        raise SystemExit(f"{range_key}: legacy distribution contract is missing")
    if not isinstance(pattern, list) or not pattern:
        raise SystemExit(f"{range_key}: weekday_hour_pattern is missing or empty")
'; then
    echo "ERROR: ${label} price-statistics response failed contract validation on port ${port}." >&2
    return 1
  fi

  info "${label} price-statistics contract is valid"
}

# ---------------------------------------------------------------------------
# Step 1: Back up notification profiles locally
# ---------------------------------------------------------------------------
step "Backing up notification profiles from $SERVER"

mkdir -p "$NOTIFICATION_BACKUP_DIR"
backup_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
notification_backup_file="${NOTIFICATION_BACKUP_DIR}/notification-profiles-${backup_timestamp}.json"

if ! ssh "$SERVER" "test -s '$NOTIFICATION_PROFILE_STORE'"; then
  echo "ERROR: Missing or empty notification profile store on server: $NOTIFICATION_PROFILE_STORE" >&2
  echo "Aborting before deploy because notification profiles are the only non-restorable data." >&2
  exit 1
fi

scp -o Compression=no "$SERVER:$NOTIFICATION_PROFILE_STORE" "$notification_backup_file"

if ! python3 -m json.tool "$notification_backup_file" >/dev/null; then
  echo "ERROR: Downloaded notification profile backup is not valid JSON: $notification_backup_file" >&2
  exit 1
fi

info "Saved notification profile backup: $notification_backup_file"

# ---------------------------------------------------------------------------
# Step 2: Build green image on the server
# ---------------------------------------------------------------------------
step "Building green image '$GREEN_IMAGE' on $SERVER"

remote_build_platform_arg=""
if [ -n "$PLATFORM" ]; then
  remote_build_platform_arg="--platform '$PLATFORM'"
fi

tar \
  --exclude='./.venv' \
  --exclude='./__pycache__' \
  --exclude='*.pyc' \
  --exclude='./.DS_Store' \
  --exclude='./dist' \
  --exclude='./build' \
  -czf - . | ssh "$SERVER" "$REMOTE_DOCKER build $remote_build_platform_arg -t '$GREEN_IMAGE' -"

# ---------------------------------------------------------------------------
# Step 3: Start green API only
# ---------------------------------------------------------------------------
step "Starting green API on port $GREEN_PORT"

ssh "$SERVER" \
  "GREEN_IMAGE='$GREEN_IMAGE' HOST_ROOT='$HOST_ROOT' GREEN_PORT='$GREEN_PORT' \
   GREEN_API='$GREEN_API' GREEN_NOTIFICATIONS='$GREEN_NOTIFICATIONS' GREEN_REFRESHER='$GREEN_REFRESHER' \
   REMOTE_DOCKER='$REMOTE_DOCKER' bash -s" <<'REMOTE'
set -euo pipefail

$REMOTE_DOCKER rm -f "$GREEN_API" "$GREEN_NOTIFICATIONS" "$GREEN_REFRESHER" 2>/dev/null || true

$REMOTE_DOCKER run -d \
  --name "$GREEN_API" \
  --restart unless-stopped \
  -p "127.0.0.1:${GREEN_PORT}:8000" \
  -v "${HOST_ROOT}/data:/etc/awattprice/data" \
  -v "${HOST_ROOT}/logs:/etc/awattprice/logs" \
  -v "${HOST_ROOT}/encryption_key.p8:/etc/awattprice/encryption_key.p8:ro" \
  -v "${HOST_ROOT}/config.ini:/etc/awattprice/config.ini:ro" \
  -v "${HOST_ROOT}/entsoe-token.txt:/etc/awattprice/entsoe-token.txt:ro" \
  --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 \
  "$GREEN_IMAGE" \
  gunicorn --workers 1 --access-logfile - \
    --access-logformat '%(t)s %(h)s - "%(r)s" %(s)s' \
    --bind 0.0.0.0:8000 -k uvicorn.workers.UvicornWorker awattprice.api:app
REMOTE

# ---------------------------------------------------------------------------
# Step 4: Smoke-test green
# ---------------------------------------------------------------------------
step "Smoke-testing green API (waiting up to 20s)"

for i in $(seq 1 20); do
  STATUS=$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${GREEN_PORT}/prices/AT" 2>/dev/null || true)
  if [ "$STATUS" = "200" ]; then
    info "Green responded 200 OK after ${i}s"
    break
  fi
  if [ "$i" -eq 20 ]; then
    echo "ERROR: Green API did not respond with 200 after 20s (got: $STATUS). Aborting." >&2
    echo "Stopping green containers..." >&2
    ssh "$SERVER" "$REMOTE_DOCKER rm -f '$GREEN_API' '$GREEN_NOTIFICATIONS' '$GREEN_REFRESHER' 2>/dev/null || true" >&2
    exit 1
  fi
  sleep 1
done

for path in "/areas/" "/prices/AT" "/generation-mix/DE-LU/history?hours=168"; do
  STATUS=$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:${GREEN_PORT}${path}'" 2>/dev/null || true)
  if [ "$STATUS" != "200" ]; then
    echo "ERROR: Green smoke test failed for ${path} (got: $STATUS). Aborting." >&2
    ssh "$SERVER" "$REMOTE_DOCKER rm -f '$GREEN_API' '$GREEN_NOTIFICATIONS' '$GREEN_REFRESHER' 2>/dev/null || true" >&2
    exit 1
  fi
  info "Green ${path} responded 200 OK"
done

if ! verify_price_statistics_contract "$GREEN_PORT" "Green"; then
  ssh "$SERVER" "$REMOTE_DOCKER rm -f '$GREEN_API' '$GREEN_NOTIFICATIONS' '$GREEN_REFRESHER' 2>/dev/null || true" >&2
  exit 1
fi

ssh "$SERVER" "curl -s http://127.0.0.1:${GREEN_PORT}/prices/AT" | python3 -m json.tool | sed -n '1,6p'

# ---------------------------------------------------------------------------
# Confirmation before cutting over live traffic
# ---------------------------------------------------------------------------
echo
echo "Green is healthy on port $GREEN_PORT."
echo "Blue is still live on port $BLUE_PORT."
confirm=""
read -r -p "==> Cut over nginx to green? [y/N] " confirm || true
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborting. Stopping green containers."
  ssh "$SERVER" "$REMOTE_DOCKER rm -f '$GREEN_API' '$GREEN_NOTIFICATIONS' '$GREEN_REFRESHER'"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 5: Switch nginx to green (zero-downtime graceful reload)
# ---------------------------------------------------------------------------
step "Switching nginx: port $BLUE_PORT -> $GREEN_PORT"

ssh "$SERVER" \
  "NGINX_CONF='$NGINX_CONF' BLUE_PORT='$BLUE_PORT' GREEN_PORT='$GREEN_PORT' bash -s" <<'REMOTE'
set -euo pipefail
if [ ! -f "$NGINX_CONF" ]; then
  echo "Nginx config not found: $NGINX_CONF" >&2
  exit 1
fi
matches=$(grep -c "proxy_pass http://127.0.0.1:${BLUE_PORT}/" "$NGINX_CONF" || true)
if [ "$matches" -ne 1 ]; then
  echo "Expected exactly one nginx proxy_pass for port ${BLUE_PORT}, found ${matches} in ${NGINX_CONF}." >&2
  exit 1
fi
sudo cp "$NGINX_CONF" "/tmp/$(basename "$NGINX_CONF").bak-before-v3-blue-green"
sudo sed -i "s|proxy_pass http://127.0.0.1:${BLUE_PORT}/|proxy_pass http://127.0.0.1:${GREEN_PORT}/|" "$NGINX_CONF"
sudo nginx -t && sudo nginx -s reload
REMOTE

info "Live traffic is now on green (port $GREEN_PORT)."

# ---------------------------------------------------------------------------
# Step 6: Stop blue API only
# ---------------------------------------------------------------------------
step "Stopping blue API"
ssh "$SERVER" "$REMOTE_DOCKER stop '$BLUE_API'"

# ---------------------------------------------------------------------------
# Step 7: Normalise API — retag and restart compose API on blue port
# ---------------------------------------------------------------------------
step "Normalising API: retagging and restarting compose API on port $BLUE_PORT"

# Upload updated compose file
ssh "$SERVER" "mkdir -p '$COMPOSE_ROOT'"
scp -o Compression=no compose.v3.yaml "$SERVER:$COMPOSE_ROOT/compose.yaml"

ssh "$SERVER" \
  "IMAGE='$IMAGE' GREEN_IMAGE='$GREEN_IMAGE' HOST_ROOT='$HOST_ROOT' \
   COMPOSE_ROOT='$COMPOSE_ROOT' GREEN_API='$GREEN_API' \
   GREEN_NOTIFICATIONS='$GREEN_NOTIFICATIONS' GREEN_REFRESHER='$GREEN_REFRESHER' \
   REMOTE_DOCKER='$REMOTE_DOCKER' REMOTE_COMPOSE='$REMOTE_COMPOSE' bash -s" <<'REMOTE'
set -euo pipefail
# Retag green as the new canonical image
$REMOTE_DOCKER tag "$GREEN_IMAGE" "$IMAGE"

# Start canonical compose API on the blue port while nginx still points to green.
cd "$COMPOSE_ROOT"
AWATTPRICE_IMAGE="$IMAGE" \
AWATTPRICE_HOST_ROOT="$HOST_ROOT" \
$REMOTE_COMPOSE up -d --force-recreate --remove-orphans api
REMOTE

step "Verifying compose API on port $BLUE_PORT"
for i in $(seq 1 30); do
  STATUS=$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:${BLUE_PORT}/areas/'" 2>/dev/null || true)
  if [ "$STATUS" = "200" ]; then
    info "Compose API responded 200 OK after ${i}s"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Compose API did not respond with 200 on port ${BLUE_PORT} after 30s (got: $STATUS)." >&2
    echo "Leaving nginx on green port ${GREEN_PORT}; inspect compose logs before retrying." >&2
    exit 1
  fi
  sleep 1
done

for path in "/areas/" "/prices/AT" "/generation-mix/DE-LU/history?hours=168"; do
  STATUS=$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:${BLUE_PORT}${path}'" 2>/dev/null || true)
  if [ "$STATUS" != "200" ]; then
    echo "ERROR: Compose API smoke test failed for ${path} on port ${BLUE_PORT} (got: $STATUS)." >&2
    echo "Leaving nginx on green port ${GREEN_PORT}; inspect compose logs before retrying." >&2
    exit 1
  fi
  info "Compose ${path} responded 200 OK"
done

if ! verify_price_statistics_contract "$BLUE_PORT" "Compose"; then
  echo "Leaving nginx on green port ${GREEN_PORT}; inspect compose/API logs before retrying." >&2
  exit 1
fi

step "Recreating background workers through compose while green serves traffic"
ssh "$SERVER" \
  "IMAGE='$IMAGE' HOST_ROOT='$HOST_ROOT' COMPOSE_ROOT='$COMPOSE_ROOT' \
   REMOTE_COMPOSE='$REMOTE_COMPOSE' bash -s" <<'REMOTE'
set -euo pipefail
cd "$COMPOSE_ROOT"
AWATTPRICE_IMAGE="$IMAGE" \
AWATTPRICE_HOST_ROOT="$HOST_ROOT" \
$REMOTE_COMPOSE --profile worker up -d --force-recreate notifications data-refresher
REMOTE

step "Waiting ${SETTLE_SECONDS}s for Docker worker churn to settle"
sleep "$SETTLE_SECONDS"

step "Rechecking compose API after worker restart"
for path in "/areas/" "/prices/AT" "/generation-mix/DE-LU/history?hours=168"; do
  STATUS=$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:${BLUE_PORT}${path}'" 2>/dev/null || true)
  if [ "$STATUS" != "200" ]; then
    echo "ERROR: Compose API check after worker restart failed for ${path} on port ${BLUE_PORT} (got: $STATUS)." >&2
    echo "Leaving nginx on green port ${GREEN_PORT}; inspect compose/API logs before retrying." >&2
    exit 1
  fi
  info "Compose ${path} still responded 200 OK"
done

step "Switching nginx back: port $GREEN_PORT -> $BLUE_PORT"
ssh "$SERVER" \
  "NGINX_CONF='$NGINX_CONF' BLUE_PORT='$BLUE_PORT' GREEN_PORT='$GREEN_PORT' bash -s" <<'REMOTE'
set -euo pipefail
if [ ! -f "$NGINX_CONF" ]; then
  echo "Nginx config not found: $NGINX_CONF" >&2
  exit 1
fi
matches=$(grep -c "proxy_pass http://127.0.0.1:${GREEN_PORT}/" "$NGINX_CONF" || true)
if [ "$matches" -ne 1 ]; then
  echo "Expected exactly one nginx proxy_pass for port ${GREEN_PORT}, found ${matches} in ${NGINX_CONF}." >&2
  exit 1
fi
sudo sed -i "s|proxy_pass http://127.0.0.1:${GREEN_PORT}/|proxy_pass http://127.0.0.1:${BLUE_PORT}/|" "$NGINX_CONF"
sudo nginx -t && sudo nginx -s reload
REMOTE

step "Removing temporary green containers"
ssh "$SERVER" "$REMOTE_DOCKER rm -f '$GREEN_API' '$GREEN_NOTIFICATIONS' '$GREEN_REFRESHER' 2>/dev/null || true"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
step "Deploy complete"
info "Image:      $IMAGE (retagged from $GREEN_IMAGE)"
info "Containers: compose stack on port $BLUE_PORT"
info ""
info "Verifying live endpoint..."
curl -s "https://api.awattprice.com/v3/prices/AT" | python3 -m json.tool | sed -n '1,6p'
