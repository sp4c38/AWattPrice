#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

DATA_DIR="$HOME/awattprice"
CONFIG_FILE="$DATA_DIR/config.ini"
uv sync

mkdir -p "$DATA_DIR/data" "$DATA_DIR/logs"
if [ ! -f "$DATA_DIR/entsoe-token.txt" ]; then
  echo "Missing ENTSO-E token: $DATA_DIR/entsoe-token.txt" >&2
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<EOF
[general]
log_level = DEBUG

[entsoe]
url = https://web-api.tp.entsoe.eu/api
token_file = $DATA_DIR/entsoe-token.txt

[paths]
log_dir = $DATA_DIR/logs
data_dir = $DATA_DIR/data

[apns]
team_id =
key_id =
key_file = $DATA_DIR/encryption_key.p8
EOF
fi

PYTHONPATH=src exec uv run python -m uvicorn awattprice.api:app --host 0.0.0.0 --port 8000 --reload
