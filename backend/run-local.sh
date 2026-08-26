#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ "$#" -ne 0 ]; then
  echo "Usage: ./run-local.sh" >&2
  exit 2
fi

DATA_DIR="${AWATTPRICE_LOCAL_DIR:-$HOME/awattprice-v3-local}"
CONFIG_FILE="$DATA_DIR/config.ini"
TOKEN_FILE="${AWATTPRICE_ENTSOE_TOKEN_FILE:-$DATA_DIR/entsoe-token.txt}"
uv sync

mkdir -p "$DATA_DIR/data" "$DATA_DIR/logs"
if [ ! -f "$TOKEN_FILE" ]; then
  echo "Missing ENTSO-E token: $TOKEN_FILE" >&2
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<EOF
[general]
log_level = DEBUG

[entsoe]
url = https://web-api.tp.entsoe.eu/api
token_file = $TOKEN_FILE

[paths]
log_dir = $DATA_DIR/logs
data_dir = $DATA_DIR/data

[apns]
team_id =
key_id =
key_file = $DATA_DIR/encryption_key.p8

[cronitor]
api_key =
monitor_key =
environment = local
EOF
fi

export AWATTPRICE_CONFIG_FILE="$CONFIG_FILE"
PYTHONPATH=src uv run python -m awattprice_refresher.service &
REFRESHER_PID=$!

stop_refresher() {
  kill "$REFRESHER_PID" 2>/dev/null || true
}
trap stop_refresher EXIT INT TERM

PYTHONPATH=src uv run python -m uvicorn awattprice.api:app --host 0.0.0.0 --port 8000 --reload
