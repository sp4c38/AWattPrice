#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SERVER="${1:-${AWATTPRICE_DEPLOY_TARGET:-}}"
if [ -z "$SERVER" ]; then
  echo "Usage: $0 user@server" >&2
  echo "Optional: AWATTPRICE_DEPLOY_MODE=image AWATTPRICE_RUN_WORKER=1 AWATTPRICE_HOST_PORT=8003" >&2
  exit 1
fi

IMAGE="${AWATTPRICE_IMAGE:-awattprice-backend:v3}"
DEPLOY_MODE="${AWATTPRICE_DEPLOY_MODE:-source}"
ARCHIVE="${AWATTPRICE_ARCHIVE:-/tmp/awattprice-backend-v3.tar.gz}"
REMOTE_ARCHIVE="${AWATTPRICE_REMOTE_ARCHIVE:-/tmp/awattprice-backend-v3.tar.gz}"
HOST_ROOT="${AWATTPRICE_HOST_ROOT:-/etc/awattprice-v3}"
COMPOSE_ROOT="${AWATTPRICE_COMPOSE_ROOT:-/srv/awattprice-v3}"
HOST_PORT="${AWATTPRICE_HOST_PORT:-8003}"
API_CONTAINER="${AWATTPRICE_API_CONTAINER:-awattprice-backend-v3}"
WORKER_CONTAINER="${AWATTPRICE_WORKER_CONTAINER:-awattprice-price-below-v3}"
RUN_WORKER="${AWATTPRICE_RUN_WORKER:-0}"
PLATFORM="${AWATTPRICE_DOCKER_PLATFORM:-}"
REMOTE_DOCKER="${AWATTPRICE_REMOTE_DOCKER:-docker}"
REMOTE_COMPOSE="${AWATTPRICE_REMOTE_COMPOSE:-docker compose}"

if [ "$DEPLOY_MODE" = "source" ]; then
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
elif [ "$DEPLOY_MODE" = "image" ]; then
  if [ -n "$PLATFORM" ]; then
    docker build --platform "$PLATFORM" -t "$IMAGE" .
  else
    docker build -t "$IMAGE" .
  fi

  docker save "$IMAGE" | gzip > "$ARCHIVE"
  scp -o Compression=no "$ARCHIVE" "$SERVER:$REMOTE_ARCHIVE"
else
  echo "Unsupported AWATTPRICE_DEPLOY_MODE: $DEPLOY_MODE" >&2
  exit 1
fi

ssh "$SERVER" "mkdir -p '$COMPOSE_ROOT'"
scp -o Compression=no compose.v3.yaml "$SERVER:$COMPOSE_ROOT/compose.yaml"

ssh "$SERVER" \
  "IMAGE='$IMAGE' DEPLOY_MODE='$DEPLOY_MODE' REMOTE_ARCHIVE='$REMOTE_ARCHIVE' HOST_ROOT='$HOST_ROOT' COMPOSE_ROOT='$COMPOSE_ROOT' HOST_PORT='$HOST_PORT' API_CONTAINER='$API_CONTAINER' WORKER_CONTAINER='$WORKER_CONTAINER' RUN_WORKER='$RUN_WORKER' REMOTE_DOCKER='$REMOTE_DOCKER' REMOTE_COMPOSE='$REMOTE_COMPOSE' bash -s" <<'REMOTE'
set -euo pipefail

if [ "$DEPLOY_MODE" = "image" ]; then
  gunzip -c "$REMOTE_ARCHIVE" | $REMOTE_DOCKER load
fi

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

$REMOTE_DOCKER run --rm \
  -v "$HOST_ROOT/app_data:/etc/awattprice/app_data" \
  -v "$HOST_ROOT/config.ini:/etc/awattprice/config.ini:ro" \
  -v "$HOST_ROOT/entsoe-token.txt:/etc/awattprice-v3/entsoe-token.txt:ro" \
  "$IMAGE" \
  python -c "from awattprice import configurator, database, orm; c=configurator.get_config(); e=database.get_awattprice_engine(c, ignore_database_not_found=True); orm.metadata.create_all(bind=e, checkfirst=True)"

if [ "$RUN_WORKER" = "1" ]; then
  compose_profiles="--profile worker"
else
  compose_profiles=""
fi

cd "$COMPOSE_ROOT"
AWATTPRICE_IMAGE="$IMAGE" \
AWATTPRICE_HOST_ROOT="$HOST_ROOT" \
AWATTPRICE_HOST_PORT="$HOST_PORT" \
AWATTPRICE_API_CONTAINER="$API_CONTAINER" \
AWATTPRICE_WORKER_CONTAINER="$WORKER_CONTAINER" \
$REMOTE_COMPOSE $compose_profiles up -d --remove-orphans
REMOTE
