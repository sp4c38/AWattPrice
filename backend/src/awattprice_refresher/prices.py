"""Refresh ENTSO-E price caches."""
import filelock
import httpx

from datetime import date
from typing import Optional

import arrow

from aiofile import async_open
from arrow import Arrow
from box import Box
from liteconfig import Config
from loguru import logger
from tenacity import (
    AsyncRetrying,
    retry_if_exception_type,
    stop_after_attempt,
    stop_after_delay,
    wait_exponential,
)

from awattprice import defaults
from awattprice import prices
from awattprice import utils
from awattprice.market_areas import MarketArea
from awattprice.utils import ExtendedFileLock
from awattprice.utils import log_attempts


def check_update_data(data: Optional[Box], last_update_time: Optional[Arrow], area: MarketArea) -> bool:
    """Check if current price data is due for update."""
    if data is None or len(data.prices) == 0:
        return True

    now_local = arrow.now(area.timezone)
    if not prices.has_current_price_points(data, area):
        return True

    if last_update_time is not None:
        next_update_time = last_update_time.shift(seconds=defaults.ENTSOE_COOLDOWN_INTERVAL)
        if now_local < next_update_time:
            return False

    midnight_tomorrow_local = now_local.floor("day").shift(days=+2)
    latest_price = max(data.prices, key=lambda point: point.end_timestamp)
    if latest_price.end_timestamp >= midnight_tomorrow_local:
        return False

    midnight_today_local = now_local.floor("day").shift(days=+1)
    if latest_price.end_timestamp < midnight_today_local:
        return True

    return now_local.hour >= defaults.ENTSOE_UPDATE_HOUR


def get_data_refresh_lock(area_key: str, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing current price data."""
    lock_file_name = defaults.PRICE_DATA_FILE_NAME.format(prices.area_file_key(area_key)) + ".lock"
    return ExtendedFileLock(config.paths.price_data_dir / lock_file_name)


def get_history_data_refresh_lock(area_key: str, day: date, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing one historical day."""
    lock_file_path = prices.get_history_data_path(area_key, day, config).with_suffix(".pickle.lock")
    return ExtendedFileLock(lock_file_path)


async def acquire_refresh_lock_immediate(
    lock: ExtendedFileLock, timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT
) -> bool:
    """Acquire a refresh lock immediately or wait up to timeout."""
    async_acquire = utils.async_wrap(lock.acquire)
    try:
        await async_acquire(timeout=0)
    except filelock.Timeout:
        pass
    else:
        return True

    if timeout <= 0:
        raise filelock.Timeout(lock.lock_file)

    try:
        await async_acquire(timeout=timeout)
    except filelock.Timeout:
        raise
    else:
        return False


def get_entsoe_query_params(
    area: MarketArea,
    period_start_local: Optional[Arrow] = None,
    period_end_local: Optional[Arrow] = None,
) -> dict[str, str]:
    """Build ENTSO-E price query parameters."""
    if period_start_local is None or period_end_local is None:
        now_local = arrow.now(area.timezone)
        period_start_local = now_local.floor("day")
        period_end_local = period_start_local.shift(days=+2)

    return {
        "documentType": "A44",
        "in_Domain": area.entsoe_domain,
        "out_Domain": area.entsoe_domain,
        "periodStart": period_start_local.to("UTC").format("YYYYMMDDHHmm"),
        "periodEnd": period_end_local.to("UTC").format("YYYYMMDDHHmm"),
    }


def get_history_period(area: MarketArea, day: date) -> tuple[Arrow, Arrow]:
    """Get the local start and end for a historical market-area day."""
    period_start = arrow.get(day.isoformat(), "YYYY-MM-DD", tzinfo=area.timezone)
    return period_start, period_start.shift(days=+1)


async def download_data(
    area: MarketArea,
    config: Config,
    period_start_local: Optional[Arrow] = None,
    period_end_local: Optional[Arrow] = None,
) -> Optional[bytes]:
    """Download price data from ENTSO-E."""
    query_params = get_entsoe_query_params(area, period_start_local, period_end_local)
    query_params["securityToken"] = config.entsoe.token_file.read_text().strip()
    logger.info(f"Polling {area.key} price data from ENTSO-E.")

    async with httpx.AsyncClient() as client:
        try:
            async for attempt in AsyncRetrying(
                before=log_attempts(logger.debug, "download ENTSO-E price data"),
                stop=(
                    stop_after_attempt(defaults.ENTSOE_RETRY_MAX_ATTEMPTS)
                    | stop_after_delay(defaults.ENTSOE_RETRY_STOP_DELAY)
                ),
                wait=wait_exponential(multiplier=1.5, min=0, max=4),
                retry=retry_if_exception_type(httpx.RequestError),
                reraise=True,
            ):
                with attempt:
                    response = await client.get(
                        config.entsoe.url,
                        params=query_params,
                        timeout=defaults.ENTSOE_TIMEOUT,
                    )
                    response.raise_for_status()
                    return response.content
        except Exception as exc:
            logger.exception(f"Requests failed when downloading price data: {exc}.")
            return None

    return None


async def update_last_update_time(area_key: str, config: Config):
    """Set the current price refresh timestamp."""
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(prices.area_file_key(area_key))
    file_path = config.paths.price_data_dir / file_name

    await utils.async_atomic_write_text(file_path, str(arrow.now().int_timestamp))


async def get_last_update_time(area_key: str, config: Config) -> Optional[Arrow]:
    """Get the current price refresh timestamp."""
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(prices.area_file_key(area_key))
    file_path = config.paths.price_data_dir / file_name

    try:
        async with async_open(file_path, "r") as file:
            file_content = await file.read()
    except FileNotFoundError:
        return None

    return arrow.get(int(file_content))


def check_data_new(old_data: Optional[Box], new_data: Box) -> bool:
    """Return true if the downloaded data contains newer price points."""
    if old_data is None or len(old_data.prices) == 0:
        return True

    old_latest = max(old_data.prices, key=lambda point: point.end_timestamp)
    new_latest = max(new_data.prices, key=lambda point: point.end_timestamp)
    return new_latest.end_timestamp > old_latest.end_timestamp


async def refresh_current_prices(
    stored_data: Optional[Box],
    area_key: str,
    config: Config,
    lock_timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT,
) -> Optional[Box]:
    """Download and store fresh current price data."""
    area = defaults.get_market_area(area_key)
    refresh_lock = get_data_refresh_lock(area_key, config)
    try:
        could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock, timeout=lock_timeout)
    except filelock.Timeout:
        logger.debug(f"Skipping refresh for {area.key} because another refresh is already running.")
        return None

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            downloaded_data = await download_data(area, config)
            if downloaded_data is None:
                return None
            try:
                await update_last_update_time(area_key, config)
            except Exception as exc:
                logger.exception(f"Couldn't write last update time: {exc}.")
            new_data = prices.parse_downloaded_data(area, downloaded_data)
            if not check_data_new(stored_data, new_data):
                return None
            await prices.store_data(new_data, area_key, config)
            return new_data

    refresh_lock.release()
    return await prices.get_stored_data(area_key, config)


async def refresh_history_prices(area_key: str, day: date, config: Config) -> Optional[Box]:
    """Download and store one historical price day."""
    area = defaults.get_market_area(area_key)
    stored_data = await prices.get_stored_history_data(area_key, day, config)
    if stored_data is not None:
        return stored_data

    prices.get_history_data_dir(config).mkdir(parents=True, exist_ok=True)
    refresh_lock = get_history_data_refresh_lock(area_key, day, config)
    try:
        could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock)
    except filelock.Timeout:
        return await prices.get_stored_history_data(area_key, day, config)

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            stored_data = await prices.get_stored_history_data(area_key, day, config)
            if stored_data is not None:
                return stored_data

            period_start_local, period_end_local = get_history_period(area, day)
            downloaded_data = await download_data(area, config, period_start_local, period_end_local)
            if downloaded_data is None:
                return None

            new_data = prices.parse_downloaded_data(area, downloaded_data)
            await prices.store_history_data(new_data, area_key, day, config)
            return new_data

    refresh_lock.release()
    return await prices.get_stored_history_data(area_key, day, config)
