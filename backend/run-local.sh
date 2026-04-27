#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

DATA_DIR="$HOME/awattprice"
uv sync

mkdir -p "$DATA_DIR"
if [ ! -f "$DATA_DIR/entsoe-token.txt" ]; then
  echo "Missing ENTSO-E token: $DATA_DIR/entsoe-token.txt" >&2
  exit 1
fi

export AWATTPRICE_DATA_DIR="$DATA_DIR"
PYTHONPATH=src uv run python -c "from awattprice import configurator, database, orm; c=configurator.get_config(); e=database.get_awattprice_engine(c, ignore_database_not_found=True); orm.metadata.create_all(bind=e, checkfirst=True)"
PYTHONPATH=src exec uv run uvicorn awattprice.api:app --host 0.0.0.0 --port 8000 --reload
