"""SQLite-backed storage for current and historical electricity prices."""

from __future__ import annotations

import json
import sqlite3
import time

from collections.abc import Iterable
from pathlib import Path
from typing import Any, Optional

import arrow

from box import Box
from filelock import FileLock
from liteconfig import Config

from awattprice import defaults


_SCHEMA = """
CREATE TABLE IF NOT EXISTS price_points (
    area_key TEXT NOT NULL,
    start_timestamp INTEGER NOT NULL,
    end_timestamp INTEGER NOT NULL,
    marketprice TEXT NOT NULL,
    resolution TEXT,
    sequence_position TEXT,
    is_fallback INTEGER NOT NULL DEFAULT 0,
    is_carried_forward INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (area_key, start_timestamp)
);
CREATE INDEX IF NOT EXISTS price_points_area_end
    ON price_points (area_key, end_timestamp);

CREATE TABLE IF NOT EXISTS price_datasets (
    area_key TEXT NOT NULL,
    dataset_key TEXT NOT NULL,
    period_start INTEGER NOT NULL,
    period_end INTEGER NOT NULL,
    source TEXT NOT NULL,
    display_name TEXT NOT NULL,
    entsoe_domain TEXT NOT NULL,
    timezone TEXT NOT NULL,
    currency TEXT NOT NULL,
    resolution TEXT,
    sequence_position TEXT,
    fallback_sequence_positions TEXT NOT NULL,
    fallback_price_count INTEGER NOT NULL,
    carried_forward_price_count INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (area_key, dataset_key)
);
"""

_REQUIRED_TABLES = {"price_points", "price_datasets"}
_INITIALIZED_DATABASE_PATHS: set[Path] = set()


def database_path(config: Config) -> Path:
    """Return the price database path, including compatibility with test configs."""
    data_dir = getattr(config.paths, "data_dir", None)
    if isinstance(data_dir, (str, Path)):
        return Path(data_dir) / defaults.PRICE_DATABASE_FILE_NAME
    return Path(config.paths.price_data_dir).parent / defaults.PRICE_DATABASE_FILE_NAME


def _initialize_database(path: Path) -> None:
    """Create the WAL database and schema once without racing other workers."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path in _INITIALIZED_DATABASE_PATHS and path.exists():
        return

    initialization_lock = FileLock(f"{path}.initialize.lock", timeout=30)
    with initialization_lock:
        if path in _INITIALIZED_DATABASE_PATHS and path.exists():
            return

        with sqlite3.connect(path, timeout=15) as connection:
            connection.execute("PRAGMA busy_timeout = 15000")
            journal_mode = connection.execute("PRAGMA journal_mode").fetchone()[0]
            if journal_mode.lower() != "wal":
                connection.execute("PRAGMA journal_mode = WAL")

            existing_tables = {
                row[0]
                for row in connection.execute(
                    "SELECT name FROM sqlite_master WHERE type = 'table'"
                )
            }
            if not _REQUIRED_TABLES.issubset(existing_tables):
                connection.executescript(_SCHEMA)

        _INITIALIZED_DATABASE_PATHS.add(path)


def connect(config: Config) -> sqlite3.Connection:
    """Open an initialized price database connection."""
    path = database_path(config)
    _initialize_database(path)
    connection = sqlite3.connect(path, timeout=15)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout = 15000")
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def _point_rows(area_key: str, price_data: Box, updated_at: int) -> Iterable[tuple[Any, ...]]:
    for point in price_data.prices:
        resolution = point.get("resolution", price_data.get("resolution"))
        yield (
            area_key,
            point.start_timestamp.int_timestamp,
            point.end_timestamp.int_timestamp,
            str(point.marketprice.value),
            resolution,
            point.get("sequence_position", price_data.get("sequence_position")),
            int(bool(point.get("is_fallback", False))),
            int(bool(point.get("is_carried_forward", False))),
            updated_at,
        )


def store_dataset(config: Config, area_key: str, dataset_key: str, price_data: Box) -> None:
    """Upsert a dataset and all of its intervals in one transaction."""
    if not price_data.prices:
        return
    updated_at = time.time_ns()
    period_start = min(point.start_timestamp.int_timestamp for point in price_data.prices)
    period_end = max(point.end_timestamp.int_timestamp for point in price_data.prices)
    with connect(config) as connection:
        connection.executemany(
            """
            INSERT INTO price_points (
                area_key, start_timestamp, end_timestamp, marketprice, resolution,
                sequence_position, is_fallback, is_carried_forward, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(area_key, start_timestamp) DO UPDATE SET
                end_timestamp = excluded.end_timestamp,
                marketprice = excluded.marketprice,
                resolution = excluded.resolution,
                sequence_position = excluded.sequence_position,
                is_fallback = excluded.is_fallback,
                is_carried_forward = excluded.is_carried_forward,
                updated_at = excluded.updated_at
            WHERE price_points.is_fallback = 1 OR excluded.is_fallback = 0
            """,
            _point_rows(area_key, price_data, updated_at),
        )
        connection.execute(
            """
            INSERT INTO price_datasets (
                area_key, dataset_key, period_start, period_end, source, display_name,
                entsoe_domain, timezone, currency, resolution, sequence_position,
                fallback_sequence_positions, fallback_price_count,
                carried_forward_price_count, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(area_key, dataset_key) DO UPDATE SET
                period_start = excluded.period_start,
                period_end = excluded.period_end,
                source = excluded.source,
                display_name = excluded.display_name,
                entsoe_domain = excluded.entsoe_domain,
                timezone = excluded.timezone,
                currency = excluded.currency,
                resolution = excluded.resolution,
                sequence_position = excluded.sequence_position,
                fallback_sequence_positions = excluded.fallback_sequence_positions,
                fallback_price_count = excluded.fallback_price_count,
                carried_forward_price_count = excluded.carried_forward_price_count,
                updated_at = excluded.updated_at
            """,
            (
                area_key,
                dataset_key,
                period_start,
                period_end,
                price_data.get("source", "ENTSOE"),
                price_data.get("display_name", area_key),
                price_data.get("entsoe_domain", ""),
                price_data.get("timezone", "UTC"),
                price_data.get("currency", "EUR"),
                price_data.get("resolution"),
                price_data.get("sequence_position"),
                json.dumps(list(price_data.get("fallback_sequence_positions", []))),
                int(price_data.get("fallback_price_count", 0)),
                int(price_data.get("carried_forward_price_count", 0)),
                updated_at,
            ),
        )


def load_dataset(config: Config, area_key: str, dataset_key: str) -> Optional[dict[str, Any]]:
    """Load dataset metadata and exactly the intervals covered by it."""
    with connect(config) as connection:
        dataset = connection.execute(
            "SELECT * FROM price_datasets WHERE area_key = ? AND dataset_key = ?",
            (area_key, dataset_key),
        ).fetchone()
        if dataset is None:
            return None
        points = connection.execute(
            """
            SELECT * FROM price_points
            WHERE area_key = ? AND start_timestamp >= ? AND end_timestamp <= ?
            ORDER BY start_timestamp
            """,
            (area_key, dataset["period_start"], dataset["period_end"]),
        ).fetchall()
    return {"dataset": dict(dataset), "points": [dict(point) for point in points]}


def load_points(config: Config, area_key: str, period_start: int, period_end: int) -> list[dict[str, Any]]:
    """Load all price intervals fully contained in a UTC timestamp range."""
    with connect(config) as connection:
        rows = connection.execute(
            """
            SELECT * FROM price_points
            WHERE area_key = ? AND start_timestamp >= ? AND end_timestamp <= ?
            ORDER BY start_timestamp
            """,
            (area_key, period_start, period_end),
        ).fetchall()
    return [dict(row) for row in rows]


def load_statistic_points(
    config: Config,
    area_key: str,
    period_start: int,
    period_end: int,
) -> list[dict[str, Any]]:
    """Load only the columns needed by long-term statistics."""
    with connect(config) as connection:
        rows = connection.execute(
            """
            SELECT start_timestamp, end_timestamp, marketprice
            FROM price_points
            WHERE area_key = ? AND start_timestamp >= ? AND end_timestamp <= ?
            ORDER BY start_timestamp
            """,
            (area_key, period_start, period_end),
        ).fetchall()
    return [dict(row) for row in rows]


def period_is_complete(config: Config, area_key: str, period_start: int, period_end: int) -> bool:
    """Return whether stored prices continuously cover a timestamp range."""
    cursor = period_start
    with connect(config) as connection:
        rows = connection.execute(
            """
            SELECT start_timestamp, end_timestamp FROM price_points
            WHERE area_key = ?
              AND start_timestamp >= ?
              AND start_timestamp < ?
            ORDER BY start_timestamp
            """,
            (area_key, period_start, period_end),
        ).fetchall()

    for row in rows:
        start_timestamp = row["start_timestamp"]
        end_timestamp = row["end_timestamp"]
        if start_timestamp != cursor or end_timestamp <= start_timestamp:
            return False
        cursor = end_timestamp

    return cursor == period_end


def prune_old_data(config: Config, now=None) -> int:
    """Prune prices and metadata outside the archive retention window."""
    current = now or arrow.now("UTC")
    areas = defaults.list_market_areas()
    supported_area_keys = {area.key for area in areas}
    pruned_count = 0

    with connect(config) as connection:
        # Remove the discontinued persistent statistics cache from databases
        # created by earlier development versions.
        connection.execute("DROP TABLE IF EXISTS price_statistics_cache")

        for area in areas:
            cutoff = (
                current.to(area.timezone)
                .floor("day")
                .shift(
                    years=-defaults.PRICE_ARCHIVE_YEARS,
                    months=-defaults.PRICE_ARCHIVE_RETENTION_BUFFER_MONTHS,
                )
                .int_timestamp
            )
            for table in ("price_points", "price_datasets"):
                cursor = connection.execute(
                    f"DELETE FROM {table} WHERE area_key = ? AND "
                    f"{'end_timestamp' if table == 'price_points' else 'period_end'} <= ?",
                    (area.key, cutoff),
                )
                pruned_count += cursor.rowcount

        placeholders = ",".join("?" for _ in supported_area_keys)
        for table in ("price_points", "price_datasets"):
            cursor = connection.execute(
                f"DELETE FROM {table} WHERE area_key NOT IN ({placeholders})",
                tuple(sorted(supported_area_keys)),
            )
            pruned_count += cursor.rowcount

    return pruned_count
