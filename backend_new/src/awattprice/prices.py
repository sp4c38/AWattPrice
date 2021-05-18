"""Poll and process price data."""
import json

from typing import Optional, Union

import arrow
import filelock
import httpx

from aiofile import async_open
from box import Box, BoxList
from fastapi import HTTPException
from filelock import FileLock
from liteconfig import Config
from loguru import logger

from awattprice import defaults
from awattprice import utils
from awattprice.defaults import Region


async def get_stored_data(region: Region, config: Config) -> Optional[Box]:
    """Get locally stored price data."""
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(region.name.lower())
    file_path = file_dir / file_name

    if not file_path.exists():
        logger.info("No locally cached price data exists yet.")
        return None
    if not file_path.is_file():
        logger.error(f"Stored price data path is a directory, not a file: {file_path}.")
        raise HTTPException(500)

    try:
        stored_data = await utils.read_json_file(file_path)
    except json.JSONDecodeError as exp:
        logger.warning(
            f"When reading cached price data {file_path} the content couldn't be decoded as json: {exp}."
        )
        return None

    return stored_data


def check_data_needs_update(data: Optional[Box]) -> bool:
    """Check if price data is up to date.

    :returns: True if up to date, false if not.
    """
    if data is None:
        return True

    now = arrow.now()
    next_refresh_time = data.meta.update_timestamp + defaults.AWATTAR_REFRESH_INTERVAL
    if next_refresh_time <= now.int_timestamp:
        pass
    else:
        time_remaining_refresh = next_refresh_time - now.int_timestamp
        logger.debug(
            f"Won't request aWATTar API again as there are still {time_remaining_refresh} second(s) until "
            "refresh is allowed again."
        )
        return False

    # The current price point is also counted as future price point.
    amount_future_points = 0
    for point in data.prices:
        end_timestamp = point.end_timestamp / defaults.TO_MICROSECONDS
        if end_timestamp > now.int_timestamp:
            amount_future_points += 1
    # Update if the amount of future price points is smaller or equal to this amount.
    future_points_update_amount = 24 - defaults.AWATTAR_UPDATE_HOUR
    if amount_future_points <= future_points_update_amount:
        pass
    else:
        logger.debug(f"Won't update as there are more than {future_points_update_amount} future price points.")
        return False

    return True


def get_refresh_lock(region: Region, config: Config) -> FileLock:
    """Get file lock used when refreshing price data."""
    lock_dir = config.paths.price_data_dir
    lock_file_name = defaults.PRICE_DATA_REFRESH_LOCK.format(region.name.lower())
    lock_file_path = lock_dir / lock_file_name
    lock = FileLock(lock_file_path)
    return lock


async def immediate_refresh_lock_acquire(lock, timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT) -> bool:
    """Acquire a refresh lock either immediately or with waiting.

    :raises filelock.Timeout: if the refresh token lock acquiring timed out.
    :returns: Returns as soon as the lock was acquired. Returns true if lock was acquired immediately
        and false if function had to wait until lock could be acquired.
    """
    async_acquire = utils.async_wrap(lock.acquire)

    # Check for immediate acquirement.
    try:
        await async_acquire(timeout=0)
    except filelock.Timeout:
        # Means that lock couldn't be acquired immediately.
        pass
    else:
        logger.debug("Lock acquired immediately.")
        return True

    try:
        await async_acquire(timeout=timeout)
    except filelock.Timeout as exp:
        logger.info(f"Lock couldn't be acquired at all: {exp}.")
        raise
    else:
        logger.debug("Lock acquired after waiting.")

    return False


async def download_data(region: Region, config: Config) -> Box:
    """Download current aWATTar price data."""
    region_config_section = f"awattar.{region.name.lower()}"
    url = getattr(config, region_config_section).url

    now = arrow.utcnow()
    # Only get prices of the current hour or later.
    start = now.replace(minute=0, second=0, microsecond=0)
    # Only get price up to the end of the following day (midnight following day).
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    end = day_start.shift(days=+2)

    url_parameters = {
        "start": start.int_timestamp * defaults.TO_MICROSECONDS,
        "end": end.int_timestamp * defaults.TO_MICROSECONDS,
    }
    timeout = defaults.AWATTAR_TIMEOUT

    logger.info(f"Getting {region.name.upper()} price data from {url}.")
    try:
        response = await utils.request_url("GET", url, timeout=timeout, params=url_parameters)
    except httpx.ConnectTimeout as exp:
        logger.critical(f"Timed out after {timeout}s when trying to reach {url}: {exp}.")
        raise HTTPException(503) from exp

    try:
        data_json = response.json()
    except json.JSONDecodeError as exp:
        logger.critical(f"Error decoding {url} response body {response.content} as json: {exp}.")
        raise HTTPException(500) from exp

    data = Box(data_json)

    return data


def transform_price_data(price_data_raw: Box) -> Box:
    """Transform the price data by adding, modifying or deleting data."""
    new_data = Box()

    new_data.prices = price_data_raw.data

    new_data.meta = {}
    now = arrow.now()
    new_data.meta.update_timestamp = now.int_timestamp

    return new_data


async def store_data(data: Union[Box, BoxList], region: Region, config: Config):
    """Store new price data to the filesystem."""
    store_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(region.name.lower())
    file_path = store_dir / file_name

    logger.info(f"Storing aWATTar {region.name} price data to {file_path}.")
    async with async_open(file_path, "w") as file:
        await file.write(data.to_json())


async def get_current_prices(region: Region, config: Config) -> Optional[dict]:
    """Get the current aWATTar prices.

    Current aWATTar prices may either be local or remote data.
    Remote data will be fetched if local data isn't up to date.
    """
    stored_data = await get_stored_data(region, config)
    get_new_data = check_data_needs_update(stored_data)

    price_data = None
    if get_new_data:
        refresh_lock = get_refresh_lock(region, config)
        logger.info("Local energy prices aren't up to date or don't exist. Refreshing.")
        acquire_error = False
        try:
            immediate_acquire = await immediate_refresh_lock_acquire(refresh_lock)
        except filelock.Timeout as exc:
            logger.error(f"Couldn't acquire refresh lock: {exc}.")
            acquire_error = True

        if acquire_error:
            if not stored_data:
                logger.warning("Acquire error: Responding with 500 code as no cached data exists.")
                raise HTTPException(500)

            logger.warning("Acquire error: Using cached local data as price data.")
            price_data = stored_data

        if not acquire_error:
            # See 'get_prices' doc for explanation why its important if lock was acquired immediately.
            if immediate_acquire:
                price_data_raw = await download_data(region, config)
                price_data = transform_price_data(price_data_raw)
                await store_data(price_data, region, config)
                refresh_lock.release()
            else:
                refresh_lock.release()
                price_data = await get_stored_data(region, config)
    else:
        logger.debug("Local price data still up to date.")
        price_data = stored_data

    return price_data
