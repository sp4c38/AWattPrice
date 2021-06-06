"""Poll and process price data."""
import json

from typing import Optional
from typing import Union

import arrow
import filelock
import httpx

from aiofile import async_open
from box import Box
from box import BoxList
from fastapi import HTTPException
from filelock import FileLock
from liteconfig import Config
from loguru import logger

from awattprice import defaults
from awattprice import exceptions
from awattprice import utils
from awattprice.defaults import Region


async def get_stored_data(region: Region, config: Config) -> Optional[Box]:
    """Get locally stored price data."""
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(region.value.lower())
    file_path = file_dir / file_name

    if not file_path.exists():
        logger.info(f"No locally cached {region.name} price data exists yet.")
        return None
    if not file_path.is_file():
        logger.error(f"Path of stored price data is a directory, not a file: {file_path}.")
        raise HTTPException(500)

    try:
        stored_data = await utils.read_json_file(file_path)
    except json.JSONDecodeError as exc:
        logger.warning(
            f"When reading cached price data {file_path} the content couldn't be decoded as json: {exc}."
        )
        return None

    return stored_data


def check_data_needs_update(data: Optional[Box]) -> bool:
    """Check if price data is up to date.

    :param region: Region of the price data.
    :returns: True if up to date, false if not.
    """
    if data is None:
        return True
    
    now = arrow.now()
    next_refresh_time = data.meta.new_timestamp + defaults.AWATTAR_REFRESH_INTERVAL
    if next_refresh_time <= now.int_timestamp:
        pass
    else:
        time_remaining_refresh = next_refresh_time - now.int_timestamp
        logger.debug(
            f"Won't request aWATTar API again as there are still {time_remaining_refresh} second(s) until "
            "refresh is allowed again."
        )
        return False

    if now.hour < defaults.AWATTAR_UPDATE_HOUR:
        logger.debug(f"Isn't past update hour ({defaults.AWATTAR_UPDATE_HOUR}), won't refresh price data.")
        return False

    return True


def get_refresh_lock(region: Region, config: Config) -> FileLock:
    """Get file lock used when refreshing price data."""
    lock_dir = config.paths.price_data_dir
    lock_file_name = defaults.PRICE_DATA_REFRESH_LOCK.format(region.value.lower())
    lock_file_path = lock_dir / lock_file_name
    lock = FileLock(lock_file_path)
    return lock


async def immediate_refresh_lock_acquire(
    lock: FileLock, timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT
) -> bool:
    """Acquire a refresh lock either immediately or with waiting.

    :raises filelock.Timeout: if the refresh token lock acquiring timed out.
    :returns: Returns as soon as the lock was acquired. Returns true if lock was acquired immediately
        and false if function had to wait until lock could be acquired.
    """
    async_acquire = utils.async_wrap(lock.acquire)

    try:
        await async_acquire(timeout=0)
    except filelock.Timeout:
        # Lock couldn't be acquired immediately.
        pass
    else:
        logger.debug("Lock acquired immediately.")
        return True

    try:
        await async_acquire(timeout=timeout)
    except filelock.Timeout as exc:
        logger.info(f"Lock couldn't be acquired at all: {exc}.")
        raise
    else:
        logger.debug("Lock acquired after waiting.")

    return False


async def download_data(region: Region, config: Config) -> Box:
    """Download current aWATTar price data."""
    region_config_section = f"awattar.{region.value.lower()}"
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

    logger.info(f"Getting {region.value.upper()} price data from {url}.")
    try:
        response = await utils.request_url("GET", url, timeout=timeout, params=url_parameters)
    except httpx.ConnectTimeout as exc:
        logger.critical(f"Timed out after {timeout}s when trying to reach {url}: {exc}.")
        raise HTTPException(503) from exc

    try:
        data_json = response.json()
    except json.JSONDecodeError as exc:
        logger.critical(f"Error decoding {url} response body {repr(response.content)} as json: {exc}.")
        raise HTTPException(500) from exc

    data = Box(data_json)

    return data


def general_transform_data(price_data_raw: Box) -> Box:
    """Validate price data schema and do some general transformations on the data.

    It may be required to perform extended transformations in specific cases.
    """
    utils.http_exc_validate_json_schema(price_data_raw, defaults.AWATTAR_PRICE_DATA_SCHEMA, http_code=503)

    price_data = Box()
    price_data.prices = price_data_raw.data

    return price_data


def is_new_transform_data(price_data_raw: Box):
    """Perform transformations if the data was verified to be new."""
    price_data = Box(price_data_raw)

    price_data.meta = Box()
    now = arrow.now()
    price_data.meta.new_timestamp = now.int_timestamp

    return price_data


def transform_to_respond_data(price_data: Box) -> Box:
    """Transform price data to price data which can be sent as response from the web app.

    Do this because not all data stored should also be sent in the response.
    """
    respond_price_data = Box()
    respond_price_data.prices = price_data.prices

    return respond_price_data


def check_data_new(old_data: Optional[Box], new_data: Box) -> bool:
    """Check if the new price data differentiates from the old price data."""
    if old_data is None:
        return True

    max_end_compare_key = lambda point: point.end_timestamp
    max_end_old = max(old_data.prices, key=max_end_compare_key)
    max_end_new = max(new_data.prices, key=max_end_compare_key)

    if max_end_new.end_timestamp > max_end_old.end_timestamp:
        return True
    else:
        return False


async def store_data(data: Union[Box, BoxList], region: Region, config: Config):
    """Store new price data to the filesystem."""
    store_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(region.value.lower())
    file_path = store_dir / file_name

    logger.info(f"Storing aWATTar {region.value} price data to {file_path}.")
    async with async_open(file_path, "w") as file:
        await file.write(data.to_json())


async def update_data(stored_data: Box, region: Region, config: Config):
    """Update price data when stored data was found to be outdated.

    :param stored_data: Needs to be provided because in some cases the updated data could be the
        stored data. Also, if there are no new future price points the stored data will be used instead
        of the downloaded data.
    """
    logger.info(f"Updating {region.name} price data.")
    refresh_lock = get_refresh_lock(region, config)
    refresh_lock_acquire_error = False
    try:
        immediate_acquire = await immediate_refresh_lock_acquire(refresh_lock)
    except filelock.Timeout as exc:
        if not stored_data:
            logger.warning("No local price data and refresh lock acquire error. Can't provide price data.")
            raise HTTPException(500)

        logger.warning("Using local price data but couldn't update because of refresh lock acquire error.")
        price_data = stored_data
        refresh_lock_acquire_error = True

    if not refresh_lock_acquire_error:
        # See 'get_prices' doc for explanation why its important if lock was acquired immediately.
        if immediate_acquire:
            downloaded_price_data_raw = await download_data(region, config)
            downloaded_price_data = general_transform_data(downloaded_price_data_raw)
            data_new = check_data_new(stored_data, downloaded_price_data)
            if data_new:
                price_data = downloaded_price_data
                price_data = is_new_transform_data(price_data)
                await store_data(price_data, region, config)
            else:
                price_data = stored_data
            refresh_lock.release()
        else:
            refresh_lock.release()
            price_data = await get_stored_data(region, config)    

    return price_data

async def get_current_prices(region: Region, config: Config) -> Optional[dict]:
    """Get the current aWATTar prices.

    Current aWATTar prices may either be local or remote data.
    Remote data will be fetched if local data isn't up to date.
    """
    stored_data = await get_stored_data(region, config)
    get_new_data = check_data_needs_update(stored_data)

    if get_new_data:
        price_data = await update_data(stored_data, region, config)
    else:
        logger.debug(f"Local price data for region {region.name} is still up to date.")
        price_data = stored_data

    respond_price_data = transform_to_respond_data(price_data)

    return respond_price_data
