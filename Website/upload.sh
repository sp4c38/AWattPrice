#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SERVER="${1:-}"
REMOTE_DIR="/home/webserver/awattprice/"

if [ -z "$SERVER" ]; then
  echo "Usage: $0 user@server" >&2
  exit 1
fi

ssh "$SERVER" "mkdir -p '$REMOTE_DIR'"

rsync -avz --delete \
  --exclude='.DS_Store' \
  --exclude='upload.sh' \
  ./ "$SERVER:$REMOTE_DIR"
