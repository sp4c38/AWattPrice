#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Target server as user@host, falls back to env var
SERVER="${1:-${AWATTPRICE_DEPLOY_TARGET:-}}"
if [ -z "$SERVER" ]; then
  echo "Usage: $0 user@server" >&2
  exit 1
fi

IMAGE="${AWATTPRICE_IMAGE:-awattprice-backend:v3}"
HOST_ROOT="${AWATTPRICE_HOST_ROOT:-/etc/awattprice-v3}"       # config/data on the server
COMPOSE_ROOT="${AWATTPRICE_COMPOSE_ROOT:-/srv/awattprice-v3}" # compose file location on the server
PLATFORM="${AWATTPRICE_DOCKER_PLATFORM:-}"                    # e.g. linux/arm64 for cross-build
REMOTE_DOCKER="${AWATTPRICE_REMOTE_DOCKER:-docker}"
REMOTE_COMPOSE="${AWATTPRICE_REMOTE_COMPOSE:-docker compose}"

# Build the image on the server by streaming the source tree over SSH
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
  -czf - . | ssh "$SERVER" "$REMOTE_DOCKER build $remote_build_platform_arg -t '$IMAGE' -"

# Upload the compose file
ssh "$SERVER" "mkdir -p '$COMPOSE_ROOT'"
scp -o Compression=no compose.v3.yaml "$SERVER:$COMPOSE_ROOT/compose.yaml"

# Run setup and start containers on the server
ssh "$SERVER" \
  "IMAGE='$IMAGE' HOST_ROOT='$HOST_ROOT' COMPOSE_ROOT='$COMPOSE_ROOT' REMOTE_DOCKER='$REMOTE_DOCKER' REMOTE_COMPOSE='$REMOTE_COMPOSE' bash -s" <<'REMOTE'
set -euo pipefail

# Verify required config files exist before starting
if [ ! -f "$HOST_ROOT/config.ini" ]; then
  echo "Missing config: $HOST_ROOT/config.ini" >&2
  exit 1
fi

if [ ! -f "$HOST_ROOT/entsoe-token.txt" ]; then
  echo "Missing ENTSO-E token: $HOST_ROOT/entsoe-token.txt" >&2
  exit 1
fi

if [ ! -d "$HOST_ROOT/app_data/data" ]; then
  echo "Missing data directory: $HOST_ROOT/app_data/data" >&2
  exit 1
fi

# Run DB migrations (create_all is a no-op if tables already exist)
$REMOTE_DOCKER run --rm \
  -v "$HOST_ROOT/app_data:/etc/awattprice/app_data" \
  -v "$HOST_ROOT/config.ini:/etc/awattprice/config.ini:ro" \
  -v "$HOST_ROOT/entsoe-token.txt:/etc/awattprice-v3/entsoe-token.txt:ro" \
  "$IMAGE" \
  python -c "from awattprice import configurator, database, orm; c=configurator.get_config(); e=database.get_awattprice_engine(c, ignore_database_not_found=True); orm.metadata.create_all(bind=e, checkfirst=True)" \
  2> >(grep -v "^INFO:" >&2)

cd "$COMPOSE_ROOT"
AWATTPRICE_IMAGE="$IMAGE" \
AWATTPRICE_HOST_ROOT="$HOST_ROOT" \
$REMOTE_COMPOSE --profile worker up -d --remove-orphans
REMOTE
