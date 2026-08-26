"""SQLite-backed storage for current and historical electricity prices."""

from __future__ import annotations

import json
import sqlite3
import time

from collections.abc import Iterable
from pathlib import Path
from typing import Any, Optional

from box import Box
from liteconfig import Config

from awattprice import defaults


def database_path(config: Config) -> Path:
    """Return the price database path, including compatibility with test configs."""
    data_dir = getattr(config.paths, "data_dir", None)
    if isinstance(data_dir, (str, Path)):
        return Path(data_dir) / defaults.PRICE_DATABASE_FILE_NAME
    return Path(config.paths.price_data_dir).parent / defaults.PRICE_DATABASE_FILE_NAME


def connect(config: Config) -> sqlite3.Connection:
    """Open and initialise a price database connection."""
    path = database_path(config)
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path, timeout=15)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA journal_mode = WAL")
    connection.execute("PRAGMA busy_timeout = 15000")
    connection.execute("PRAGMA foreign_keys = ON")
    connection.executescript(
        """
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

        CREATE TABLE IF NOT EXISTS price_history_imports (
            area_key TEXT NOT NULL,
            period_start INTEGER NOT NULL,
            period_end INTEGER NOT NULL,
            state TEXT NOT NULL,
            point_count INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL,
            last_error TEXT,
            PRIMARY KEY (area_key, period_start, period_end)
        );

        CREATE TABLE IF NOT EXISTS price_statistics_cache (
            cache_key TEXT PRIMARY KEY,
            area_key TEXT NOT NULL,
            cutoff_timestamp INTEGER NOT NULL,
            response_json TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );
        """
    )
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


def record_import(
    config: Config,
    area_key: str,
    period_start: int,
    period_end: int,
    state: str,
    point_count: int = 0,
    last_error: Optional[str] = None,
) -> None:
    """Record a resumable historical import attempt."""
    with connect(config) as connection:
        connection.execute(
            """
            INSERT INTO price_history_imports (
                area_key, period_start, period_end, state, point_count, updated_at, last_error
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(area_key, period_start, period_end) DO UPDATE SET
                state = excluded.state,
                point_count = excluded.point_count,
                updated_at = excluded.updated_at,
                last_error = excluded.last_error
            """,
            (area_key, period_start, period_end, state, point_count, int(time.time()), last_error),
        )


def import_is_complete(config: Config, area_key: str, period_start: int, period_end: int) -> bool:
    """Return whether one historical import range completed successfully."""
    with connect(config) as connection:
        row = connection.execute(
            """
            SELECT state FROM price_history_imports
            WHERE area_key = ? AND period_start = ? AND period_end = ?
            """,
            (area_key, period_start, period_end),
        ).fetchone()
    return row is not None and row["state"] == "complete"


def get_cached_statistics(config: Config, cache_key: str, cutoff_timestamp: int) -> Optional[dict[str, Any]]:
    """Get a statistics response if it was produced for the same data cutoff."""
    with connect(config) as connection:
        row = connection.execute(
            """
            SELECT response_json FROM price_statistics_cache
            WHERE cache_key = ? AND cutoff_timestamp = ?
            """,
            (cache_key, cutoff_timestamp),
        ).fetchone()
    return json.loads(row["response_json"]) if row else None


def store_cached_statistics(
    config: Config,
    cache_key: str,
    area_key: str,
    cutoff_timestamp: int,
    response: dict[str, Any],
) -> None:
    """Store a computed statistics response."""
    with connect(config) as connection:
        connection.execute(
            """
            INSERT INTO price_statistics_cache (
                cache_key, area_key, cutoff_timestamp, response_json, created_at
            ) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(cache_key) DO UPDATE SET
                area_key = excluded.area_key,
                cutoff_timestamp = excluded.cutoff_timestamp,
                response_json = excluded.response_json,
                created_at = excluded.created_at
            """,
            (cache_key, area_key, cutoff_timestamp, json.dumps(response), int(time.time())),
        )
