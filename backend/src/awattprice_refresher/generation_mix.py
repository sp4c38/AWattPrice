"""Refresh ENTSO-E generation mix caches."""
import asyncio
import filelock
import httpx

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
    wait_fixed,
)

from awattprice import defaults
from awattprice import generation_mix
from awattprice.prices import area_file_key
from awattprice.utils import ExtendedFileLock
from awattprice.utils import log_attempts
from awattprice.market_areas import MarketArea


def check_update_data(data: Optional[Box], last_update_time: Optional[Arrow], area: MarketArea) -> bool:
    """Check if generation data should be refreshed."""
    if data is None or len(data.generation_points) == 0:
        return True

    now_local = arrow.now(area.timezone)
    if last_update_time is not None:
        next_update_time = last_update_time.shift(seconds=defaults.ENTSOE_GENERATION_COOLDOWN_INTERVAL)
        if now_local < next_update_time:
            return False

    latest_point = max(data.generation_points, key=lambda point: point.end_timestamp)
    return latest_point.end_timestamp < now_local.shift(minutes=-30)


def get_data_refresh_lock(area_key: str, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing generation data."""
    lock_file_name = defaults.GENERATION_DATA_FILE_NAME.format(area_file_key(area_key)) + ".lock"
    return ExtendedFileLock(config.paths.generation_data_dir / lock_file_name)


async def acquire_refresh_lock_immediate(
    lock: ExtendedFileLock, timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT
) -> bool:
    """Acquire the refresh lock either immediately or with waiting."""
    async_acquire = asyncio.to_thread
    try:
        await async_acquire(lock.acquire, timeout=0)
    except filelock.Timeout:
        pass
    else:
        return True

    if timeout <= 0:
        raise filelock.Timeout(lock.lock_file)

    try:
        await async_acquire(lock.acquire, timeout=timeout)
    except filelock.Timeout:
        raise
    else:
        return False


def get_entsoe_query_params(area: MarketArea) -> dict[str, str]:
    """Build ENTSO-E actual generation per production type query parameters."""
    now_local = arrow.now(area.timezone)
    period_start_local = now_local.shift(hours=-168)
    period_end_local = now_local.shift(hours=+1)

    return {
        "documentType": "A75",
        "processType": "A16",
        "in_Domain": area.entsoe_domain,
        "periodStart": period_start_local.to("UTC").format("YYYYMMDDHHmm"),
        "periodEnd": period_end_local.to("UTC").format("YYYYMMDDHHmm"),
    }


async def download_data(area: MarketArea, config: Config) -> Optional[bytes]:
    """Download generation mix data from the ENTSO-E API."""
    query_params = get_entsoe_query_params(area)
    query_params["securityToken"] = config.entsoe.token_file.read_text().strip()

    logger.info(f"Polling {area.key} generation mix data from ENTSO-E.")
    try:
        async for attempt in AsyncRetrying(
            before=log_attempts(logger.debug, "download ENTSO-E generation mix data"),
            wait=wait_fixed(3) + wait_exponential(multiplier=1, min=2, max=10),
            stop=(stop_after_attempt(defaults.ENTSOE_RETRY_MAX_ATTEMPTS) | stop_after_delay(defaults.ENTSOE_RETRY_STOP_DELAY)),
            retry=retry_if_exception_type(httpx.RequestError),
            reraise=True,
        ):
            with attempt:
                async with httpx.AsyncClient(http2=True) as client:
                    response = await client.get(
                        config.entsoe.url,
                        params=query_params,
                        timeout=defaults.ENTSOE_TIMEOUT,
                    )
                    response.raise_for_status()
                    return response.content
    except httpx.RequestError as exc:
        logger.exception(f"Requests failed when downloading generation mix data: {exc}.")
        return None

    return None


async def update_last_update_time(area_key: str, config: Config):
    """Set the generation data update timestamp to now."""
    file_name = defaults.GENERATION_DATA_UPDATE_TS_FILE_NAME.format(area_file_key(area_key))
    file_path = config.paths.generation_data_dir / file_name

    async with async_open(file_path, "w") as file:
        await file.write(str(arrow.now().int_timestamp))


async def get_last_update_time(area_key: str, config: Config) -> Optional[Arrow]:
    """Get time the generation data was updated last."""
    file_name = defaults.GENERATION_DATA_UPDATE_TS_FILE_NAME.format(area_file_key(area_key))
    file_path = config.paths.generation_data_dir / file_name

    try:
        async with async_open(file_path, "r") as file:
            file_content = await file.read()
    except FileNotFoundError:
        return None

    return arrow.get(int(file_content))


def check_data_new(old_data: Optional[Box], new_data: Box) -> bool:
    """Check if downloaded generation data has a newer interval."""
    if old_data is None or len(old_data.generation_points) == 0:
        return True

    old_latest = max(old_data.generation_points, key=lambda point: point.end_timestamp)
    new_latest = max(new_data.generation_points, key=lambda point: point.end_timestamp)
    return new_latest.end_timestamp > old_latest.end_timestamp


async def refresh_generation_mix(
    stored_data: Optional[Box],
    area_key: str,
    config: Config,
    lock_timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT,
) -> Optional[Box]:
    """Download and store the latest generation mix data."""
    area = defaults.get_market_area(area_key)
    refresh_lock = get_data_refresh_lock(area_key, config)
    try:
        could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock, timeout=lock_timeout)
    except filelock.Timeout:
        logger.debug(f"Skipping generation refresh for {area.key} because another refresh is running.")
        return None

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            downloaded_data = await download_data(area, config)
            if downloaded_data is None:
                return None
            new_data = generation_mix.parse_downloaded_data(area, downloaded_data)
            try:
                await update_last_update_time(area_key, config)
            except Exception as exc:
                logger.exception(f"Couldn't write generation update time: {exc}.")
            if not check_data_new(stored_data, new_data):
                return None
            await generation_mix.store_data(new_data, area_key, config)
            return new_data

    refresh_lock.release()
    return await generation_mix.get_stored_data(area_key, config)
