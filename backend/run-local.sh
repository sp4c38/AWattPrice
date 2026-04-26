#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

uv sync

mkdir -p "$HOME/.config/awattprice"
if [ ! -f "$HOME/.config/awattprice/entsoe-token.txt" ]; then
  echo "Missing ENTSO-E token: ~/.config/awattprice/entsoe-token.txt" >&2
  exit 1
fi

PYTHONPATH=src uv run python misc/generate_database.py
PYTHONPATH=src exec uv run uvicorn awattprice.api:app --host 0.0.0.0 --port 8000 --reload
