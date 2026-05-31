"""Track cache refresh status and report cache coverage."""
import sqlite3

from contextlib import closing
from datetime import date
from pathlib import Path
from typing import Optional

import arrow

from box import Box
from box import BoxList
from liteconfig import Config
from loguru import logger

from awattprice import defaults
from awattprice import generation_mix
from awattprice import prices
from awattprice.market_areas import MarketArea


DATASET_CURRENT_PRICES = "current_prices"
DATASET_PRICE_HISTORY = "price_history"
DATASET_GENERATION_MIX = "generation_mix"
DATASET_CACHE_CLEANUP = "cache_cleanup"

STATE_FRESH = "fresh"
STATE_STALE_BUT_SERVED = "stale_but_served"
STATE_TEMPORARILY_FAILED = "temporarily_failed"
STATE_UNSUPPORTED_OR_NO_DATA = "unsupported_or_no_data"
STATE_RATE_LIMITED = "rate_limited"


def cache_index_path(config: Config) -> Path:
    """Return the SQLite path for cache metadata."""
    return config.paths.data_dir / defaults.CACHE_INDEX_FILE_NAME


def connect(config: Config) -> sqlite3.Connection:
    """Open the cache metadata database and ensure its schema."""
    config.paths.data_dir.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(cache_index_path(config))
    connection.row_factory = sqlite3.Row
    ensure_schema(connection)
    return connection


def ensure_schema(connection: sqlite3.Connection):
    """Create cache metadata tables when needed."""
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS cache_records (
            area_key TEXT NOT NULL,
            dataset TEXT NOT NULL,
            period TEXT NOT NULL,
            state TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            coverage_start INTEGER,
            coverage_end INTEGER,
            last_error TEXT,
            next_retry_at INTEGER,
            pruned_count INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (area_key, dataset, period)
        )
        """
    )
    connection.commit()


def _timestamp(value) -> Optional[int]:
    if value is None:
        return None
    return value.int_timestamp


def _coverage_from_prices(price_data: Box) -> tuple[Optional[int], Optional[int]]:
    if not price_data or not price_data.prices:
        return None, None
    return (
        min(point.start_timestamp for point in price_data.prices).int_timestamp,
        max(point.end_timestamp for point in price_data.prices).int_timestamp,
    )


def record_cache_result(
    config: Config,
    area_key: str,
    dataset: str,
    period: str = "current",
    state: str = STATE_FRESH,
    coverage_start: Optional[int] = None,
    coverage_end: Optional[int] = None,
    last_error: Optional[str] = None,
    next_retry_at: Optional[int] = None,
    pruned_count: int = 0,
):
    """Upsert one cache metadata row."""
    with closing(connect(config)) as connection:
        connection.execute(
            """
            INSERT INTO cache_records (
                area_key, dataset, period, state, updated_at, coverage_start,
                coverage_end, last_error, next_retry_at, pruned_count
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(area_key, dataset, period) DO UPDATE SET
                state = excluded.state,
                updated_at = excluded.updated_at,
                coverage_start = excluded.coverage_start,
                coverage_end = excluded.coverage_end,
                last_error = excluded.last_error,
                next_retry_at = excluded.next_retry_at,
                pruned_count = excluded.pruned_count
            """,
            (
                area_key,
                dataset,
                period,
                state,
                arrow.now().int_timestamp,
                coverage_start,
                coverage_end,
                last_error,
                next_retry_at,
                pruned_count,
            ),
        )
        connection.commit()


def record_price_success(config: Config, area_key: str, price_data: Box):
    """Record current price cache coverage."""
    area = defaults.get_market_area(area_key)
    coverage_start, coverage_end = _coverage_from_prices(price_data)
    record_cache_result(
        config,
        area_key,
        DATASET_CURRENT_PRICES,
        state=STATE_FRESH if prices.has_current_price_points(price_data, area) else STATE_TEMPORARILY_FAILED,
        coverage_start=coverage_start,
        coverage_end=coverage_end,
    )


def record_history_success(config: Config, area_key: str, day: date, price_data: Box):
    """Record historical price cache coverage."""
    coverage_start, coverage_end = _coverage_from_prices(price_data)
    record_cache_result(
        config,
        area_key,
        DATASET_PRICE_HISTORY,
        period=day.isoformat(),
        coverage_start=coverage_start,
        coverage_end=coverage_end,
    )


def record_generation_success(config: Config, area_key: str, metadata: Box):
    """Record generation mix cache coverage."""
    record_cache_result(
        config,
        area_key,
        DATASET_GENERATION_MIX,
        coverage_start=metadata.get("coverage_start"),
        coverage_end=metadata.get("coverage_end"),
    )


def record_failure(
    config: Config,
    area_key: str,
    dataset: str,
    error: Exception | str,
    period: str = "current",
    state: str = STATE_TEMPORARILY_FAILED,
    next_retry_at: Optional[int] = None,
):
    """Record a failed cache refresh without deleting the last good payload."""
    record_cache_result(
        config,
        area_key,
        dataset,
        period=period,
        state=state,
        last_error=str(error),
        next_retry_at=next_retry_at,
    )


def record_prune_result(config: Config, pruned_count: int):
    """Record the last cleanup result."""
    record_cache_result(
        config,
        "_global",
        DATASET_CACHE_CLEANUP,
        state=STATE_FRESH,
        pruned_count=pruned_count,
    )


def get_records(config: Config) -> dict[tuple[str, str, str], sqlite3.Row]:
    """Return all cache metadata rows keyed by area, dataset, and period."""
    with closing(connect(config)) as connection:
        rows = connection.execute("SELECT * FROM cache_records").fetchall()
    return {(row["area_key"], row["dataset"], row["period"]): row for row in rows}


def latest_history_days(now=None) -> list[date]:
    """Return the latest completed Berlin dates retained in cache."""
    now_berlin = now or arrow.now(defaults.REFRESHER_TIMEZONE)
    yesterday = now_berlin.floor("day").shift(days=-1)
    return [
        yesterday.shift(days=-offset).date()
        for offset in range(defaults.PRICE_HISTORY_RETENTION_DAYS)
    ]


async def area_cache_summary(area: MarketArea, config: Config, records: dict) -> Box:
    """Build cache status for one market area."""
    summary = Box()
    summary.area = area.key
    summary.display_name = area.display_name
    summary.current_prices = await current_price_summary(area, config, records)
    summary.price_history = await price_history_summary(area, config, records)
    summary.generation_mix = await generation_mix_summary(area, config, records)
    return summary


async def current_price_summary(area: MarketArea, config: Config, records: dict) -> Box:
    """Build current price cache status for one area."""
    stored_data = await prices.get_stored_data(area.key, config)
    record = records.get((area.key, DATASET_CURRENT_PRICES, "current"))
    status = Box()
    status.present = stored_data is not None
    status.has_current_prices = prices.has_current_price_points(stored_data, area)
    if stored_data is not None and stored_data.prices:
        status.coverage_start, status.coverage_end = _coverage_from_prices(stored_data)
    status.state = record["state"] if record else None
    status.last_error = record["last_error"] if record else None
    status.next_retry_at = record["next_retry_at"] if record else None
    return status


async def price_history_summary(area: MarketArea, config: Config, records: dict) -> Box:
    """Build retained history cache status for one area."""
    days = latest_history_days()
    entries = BoxList()
    missing_days = []
    for history_day in days:
        stored_data = await prices.get_stored_history_data(area.key, history_day, config)
        record = records.get((area.key, DATASET_PRICE_HISTORY, history_day.isoformat()))
        entry = Box()
        entry.date = history_day.isoformat()
        entry.present = stored_data is not None
        entry.state = record["state"] if record else None
        entry.last_error = record["last_error"] if record else None
        if stored_data is not None and stored_data.prices:
            entry.coverage_start, entry.coverage_end = _coverage_from_prices(stored_data)
        else:
            missing_days.append(entry.date)
        entries.append(entry)

    return Box({"retained_days": entries, "missing_days": missing_days})


async def generation_mix_summary(area: MarketArea, config: Config, records: dict) -> Box:
    """Build generation mix cache status for one area."""
    stored_metadata = await generation_mix.get_stored_metadata(area.key, config)
    stored_response_json = await generation_mix.get_stored_history_response_json(
        area.key,
        defaults.GENERATION_RETENTION_HOURS,
        config,
    )
    record = records.get((area.key, DATASET_GENERATION_MIX, "current"))
    status = Box()
    status.present = stored_metadata is not None and stored_response_json is not None
    if stored_metadata is not None:
        status.coverage_start = stored_metadata.get("coverage_start")
        status.coverage_end = stored_metadata.get("coverage_end")
        status.history_hours = stored_metadata.get("history_hours")
        status.interval_count = stored_metadata.get("interval_count")
        status.latest_generation_end = stored_metadata.get("latest_generation_end")
    status.state = record["state"] if record else None
    status.last_error = record["last_error"] if record else None
    status.next_retry_at = record["next_retry_at"] if record else None
    return status


async def cache_status_response(config: Config) -> Box:
    """Return cache status for every supported market area."""
    records = get_records(config)
    areas = BoxList()
    for area in defaults.list_market_areas():
        try:
            areas.append(await area_cache_summary(area, config, records))
        except Exception as exc:
            logger.exception(f"Couldn't build cache status for {area.key}: {exc}.")

    cleanup_record = records.get(("_global", DATASET_CACHE_CLEANUP, "current"))
    cleanup = Box()
    cleanup.pruned_count = cleanup_record["pruned_count"] if cleanup_record else 0
    cleanup.updated_at = cleanup_record["updated_at"] if cleanup_record else None

    return Box(
        {
            "timezone": defaults.REFRESHER_TIMEZONE,
            "history_retention_days": defaults.PRICE_HISTORY_RETENTION_DAYS,
            "areas": areas,
            "cleanup": cleanup,
        }
    )
