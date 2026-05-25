"""Warm AWattPrice caches on a global Berlin-time schedule."""
import asyncio
import random

from datetime import date
from pathlib import Path
from typing import Awaitable
from typing import Callable
from typing import Optional

import arrow

from box import Box
from liteconfig import Config
from loguru import logger

from awattprice import cache_status
from awattprice import configurator
from awattprice import defaults
from awattprice import generation_mix
from awattprice import prices
from awattprice.market_areas import MarketArea
from awattprice_refresher import generation_mix as generation_mix_refresher
from awattprice_refresher import prices as prices_refresher


AWATTPRICE_REFRESHER_SERVICE_NAME = "awattprice-refresher"


def now_berlin():
    """Return the scheduler clock in Europe/Berlin."""
    return arrow.now(defaults.REFRESHER_TIMEZONE)


def fast_price_poll_window(now=None) -> bool:
    """Return true in the global 13:00-15:00 Berlin fast polling window."""
    current = now or now_berlin()
    return (
        defaults.REFRESHER_FAST_POLL_START_HOUR
        <= current.hour
        < defaults.REFRESHER_FAST_POLL_END_HOUR
    )


def current_price_poll_interval(now=None) -> int:
    """Return the current price polling interval for the global schedule."""
    if fast_price_poll_window(now):
        return defaults.REFRESHER_FAST_POLL_INTERVAL_SECONDS
    return defaults.REFRESHER_SLOW_POLL_INTERVAL_SECONDS


def due(last_run_at: Optional[arrow.Arrow], interval_seconds: int, now=None) -> bool:
    """Return whether a scheduled task should run."""
    current = now or now_berlin()
    if last_run_at is None:
        return True
    return (current - last_run_at).total_seconds() >= interval_seconds


def retained_history_days(now=None) -> list[date]:
    """Return historical Berlin dates that should remain cached."""
    return cache_status.latest_history_days(now)


def price_data_covers_tomorrow(price_data: Optional[Box], area: MarketArea, now=None) -> bool:
    """Return true when current prices cover the full next local day."""
    if price_data is None or not price_data.prices:
        return False
    current = now or arrow.now(area.timezone)
    tomorrow_end = current.to(area.timezone).floor("day").shift(days=+2)
    latest_price = max(price_data.prices, key=lambda point: point.end_timestamp)
    return latest_price.end_timestamp >= tomorrow_end


async def run_bounded(
    areas: list[MarketArea],
    worker: Callable[[MarketArea], Awaitable[None]],
    concurrency: int = defaults.REFRESHER_CONCURRENCY,
):
    """Run one per-area worker with bounded ENTSO-E concurrency."""
    semaphore = asyncio.Semaphore(concurrency)

    async def run_area(area: MarketArea):
        async with semaphore:
            await asyncio.sleep(random.uniform(0, 2))
            await worker(area)

    await asyncio.gather(*(run_area(area) for area in areas))


async def refresh_current_prices_for_area(area: MarketArea, config: Config):
    """Warm current/tomorrow price data for one area."""
    stored_data = await prices.get_stored_data(area.key, config)
    if price_data_covers_tomorrow(stored_data, area):
        cache_status.record_price_success(config, area.key, stored_data)
        logger.debug(f"Skipping {area.key} current prices because tomorrow is already cached.")
        return

    try:
        refreshed_data = await prices_refresher.refresh_current_prices(
            stored_data,
            area.key,
            config,
            lock_timeout=0,
        )
    except Exception as exc:
        logger.exception(f"Couldn't refresh current prices for {area.key}: {exc}.")
        cache_status.record_failure(
            config,
            area.key,
            cache_status.DATASET_CURRENT_PRICES,
            exc,
        )
        return

    latest_data = refreshed_data or await prices.get_stored_data(area.key, config)
    if latest_data is None:
        cache_status.record_failure(
            config,
            area.key,
            cache_status.DATASET_CURRENT_PRICES,
            "No current price data available.",
            state=cache_status.STATE_UNSUPPORTED_OR_NO_DATA,
        )
        return

    cache_status.record_price_success(config, area.key, latest_data)


async def refresh_history_for_area(area: MarketArea, config: Config):
    """Ensure retained historical price days are cached for one area."""
    for history_day in retained_history_days():
        try:
            history_data = await prices_refresher.refresh_history_prices(area.key, history_day, config)
        except Exception as exc:
            logger.exception(f"Couldn't refresh history for {area.key} {history_day}: {exc}.")
            cache_status.record_failure(
                config,
                area.key,
                cache_status.DATASET_PRICE_HISTORY,
                exc,
                period=history_day.isoformat(),
            )
            continue

        if history_data is None:
            cache_status.record_failure(
                config,
                area.key,
                cache_status.DATASET_PRICE_HISTORY,
                "No historical price data available.",
                period=history_day.isoformat(),
                state=cache_status.STATE_UNSUPPORTED_OR_NO_DATA,
            )
            continue

        cache_status.record_history_success(config, area.key, history_day, history_data)


async def refresh_generation_mix_for_area(area: MarketArea, config: Config):
    """Warm generation mix data for one area."""
    stored_data = await generation_mix.get_stored_data(area.key, config)
    try:
        refreshed_data = await generation_mix_refresher.refresh_generation_mix(
            stored_data,
            area.key,
            config,
            lock_timeout=0,
        )
    except Exception as exc:
        logger.exception(f"Couldn't refresh generation mix for {area.key}: {exc}.")
        cache_status.record_failure(
            config,
            area.key,
            cache_status.DATASET_GENERATION_MIX,
            exc,
        )
        return

    latest_data = refreshed_data or await generation_mix.get_stored_data(area.key, config)
    if latest_data is None:
        cache_status.record_failure(
            config,
            area.key,
            cache_status.DATASET_GENERATION_MIX,
            "No generation mix data available.",
            state=cache_status.STATE_UNSUPPORTED_OR_NO_DATA,
        )
        return

    cache_status.record_generation_success(config, area.key, latest_data)


def _supported_area_file_keys() -> set[str]:
    return {prices.area_file_key(area.key) for area in defaults.list_market_areas()}


def _delete_path(path: Path) -> int:
    try:
        path.unlink()
    except FileNotFoundError:
        return 0
    logger.info(f"Deleted old cache payload {path}.")
    return 1


def prune_current_price_payloads(config: Config) -> int:
    """Delete current price payloads for areas that are no longer supported."""
    supported_keys = _supported_area_file_keys()
    pruned_count = 0
    for path in config.paths.price_data_dir.glob("price-data-*.pickle"):
        area_key = path.stem.removeprefix("price-data-")
        if area_key not in supported_keys:
            pruned_count += _delete_path(path)
    return pruned_count


def prune_history_payloads(config: Config, now=None) -> int:
    """Keep only retained historical price payloads."""
    history_dir = prices.get_history_data_dir(config)
    if not history_dir.exists():
        return 0

    retained_days = {day.isoformat() for day in retained_history_days(now)}
    supported_keys = _supported_area_file_keys()
    pruned_count = 0
    for path in history_dir.glob("price-data-*.pickle"):
        cache_key = path.stem.removeprefix("price-data-")
        matched_supported_area = False
        should_keep = False
        for area_key in supported_keys:
            prefix = f"{area_key}-"
            if not cache_key.startswith(prefix):
                continue
            matched_supported_area = True
            should_keep = cache_key.removeprefix(prefix) in retained_days
            break
        if not matched_supported_area or not should_keep:
            pruned_count += _delete_path(path)
    return pruned_count


async def prune_generation_payloads(config: Config, now=None) -> int:
    """Trim generation mix payloads to the retained rolling window."""
    cutoff = (now or now_berlin()).shift(
        hours=-(defaults.GENERATION_RETENTION_HOURS + defaults.GENERATION_RETENTION_SAFETY_HOURS)
    )
    pruned_count = 0
    for area in defaults.list_market_areas():
        generation_data = await generation_mix.get_stored_data(area.key, config)
        if generation_data is None or not generation_data.generation_points:
            continue
        retained_points = [
            point for point in generation_data.generation_points
            if point.end_timestamp > cutoff
        ]
        removed_count = len(generation_data.generation_points) - len(retained_points)
        if removed_count <= 0 or len(retained_points) == 0:
            continue
        generation_data.generation_points = retained_points
        await generation_mix.store_data(generation_data, area.key, config)
        pruned_count += removed_count
    return pruned_count


def prune_cache_metadata(config: Config, now=None) -> int:
    """Delete stale metadata rows for pruned history and unsupported areas."""
    retained_days = {day.isoformat() for day in retained_history_days(now)}
    supported_area_keys = {area.key for area in defaults.list_market_areas()}
    pruned_count = 0
    with cache_status.connect(config) as connection:
        rows = connection.execute(
            "SELECT area_key, dataset, period FROM cache_records"
        ).fetchall()
        for row in rows:
            area_key = row["area_key"]
            dataset = row["dataset"]
            period = row["period"]
            if area_key == "_global":
                continue
            if area_key not in supported_area_keys:
                connection.execute(
                    "DELETE FROM cache_records WHERE area_key = ? AND dataset = ? AND period = ?",
                    (area_key, dataset, period),
                )
                pruned_count += 1
            elif dataset == cache_status.DATASET_PRICE_HISTORY and period not in retained_days:
                connection.execute(
                    "DELETE FROM cache_records WHERE area_key = ? AND dataset = ? AND period = ?",
                    (area_key, dataset, period),
                )
                pruned_count += 1
        connection.commit()
    return pruned_count


async def prune_cache(config: Config, now=None) -> int:
    """Run all cache retention rules."""
    pruned_count = 0
    pruned_count += prune_current_price_payloads(config)
    pruned_count += prune_history_payloads(config, now)
    pruned_count += await prune_generation_payloads(config, now)
    pruned_count += prune_cache_metadata(config, now)
    cache_status.record_prune_result(config, pruned_count)
    return pruned_count


class RefresherState:
    """Track last run timestamps for the in-process scheduler."""

    def __init__(self):
        self.current_prices: Optional[arrow.Arrow] = None
        self.price_history: Optional[arrow.Arrow] = None
        self.generation_mix: Optional[arrow.Arrow] = None
        self.cleanup: Optional[arrow.Arrow] = None


async def run_cycle(config: Config, state: RefresherState, now=None):
    """Run due refresher tasks once."""
    current = now or now_berlin()
    areas = defaults.list_market_areas()

    if due(state.current_prices, current_price_poll_interval(current), current):
        logger.info("Refreshing current price caches.")
        await run_bounded(areas, lambda area: refresh_current_prices_for_area(area, config))
        state.current_prices = current

    if due(state.price_history, defaults.REFRESHER_HISTORY_INTERVAL_SECONDS, current):
        logger.info("Refreshing retained price history caches.")
        await run_bounded(areas, lambda area: refresh_history_for_area(area, config))
        state.price_history = current

    if due(state.generation_mix, defaults.REFRESHER_GENERATION_INTERVAL_SECONDS, current):
        logger.info("Refreshing generation mix caches.")
        await run_bounded(areas, lambda area: refresh_generation_mix_for_area(area, config))
        state.generation_mix = current

    if due(state.cleanup, defaults.REFRESHER_SLOW_POLL_INTERVAL_SECONDS, current):
        pruned_count = await prune_cache(config, current)
        logger.info(f"Cache cleanup pruned {pruned_count} entries.")
        state.cleanup = current


async def run_forever(config: Config):
    """Run the refresher scheduler forever."""
    state = RefresherState()
    while True:
        await run_cycle(config, state)
        await asyncio.sleep(60)


async def async_main():
    """Entrypoint for the cache refresher worker."""
    config = configurator.get_config()
    configurator.configure_loguru(AWATTPRICE_REFRESHER_SERVICE_NAME, config)

    await run_forever(config)


def main():
    """Run the cache refresher worker."""
    asyncio.run(async_main())


if __name__ == "__main__":
    main()
