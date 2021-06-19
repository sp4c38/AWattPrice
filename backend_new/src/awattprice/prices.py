"""Poll and process price data."""
import asyncio
import json

from typing import Optional
from typing import Union

import arrow
import filelock
import httpx

from aiofile import async_open
from arrow import Arrow
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
    """Get locally cached price data.

    :returns: Price data wrapped as a Box. If file not found returns None.
    """
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(region.value.lower())
    file_path = file_dir / file_name

    try:
        async with async_open(file_path, "r") as file:
            data_raw = await file.read()
    except FileNotFoundError:
        return None

    try:
        data_json = json.loads(data_raw)
    except json.JSONDecodeError as exc:
        logger.exception(f"Stored price data no valid json: {file_path}.")
        raise

    data = Box(data_json)

    return data


async def get_last_update_time(region: Region, config: Config) -> Optional[Arrow]:
    """Get time the price data was updated last.

    :returns: Last update time as arrow instance. If file not found returns None.
    """
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(region.name.lower())
    file_path = file_dir / file_name

    try:
        async with async_open(file_path, "r") as file:
            file_content = await file.read()
    except FileNotFoundError:
        return None

    try:
        timestamp = int(file_content)
    except ValueError as exc:
        logger.exception(f"Last update timestamp in file {file_path} is no valid integer: {file_content}.")
        raise

    # Accepts negative values for pre-unix times, thus won't raise.
    time = arrow.get(timestamp)

    return time


def check_update_data(data: Optional[Box], last_update_time: Optional[Arrow]) -> bool:
    """Check if the parsed price data is allowed to be updated.

    :param last_update_ts: Timestamp the data was last polled from the awattar api.
    :returns: True if data should be updated, false if it's not due.
    """
    if data is None:
        return True

    now_berlin = arrow.now("Europe/Berlin")
    if now_berlin.hour < defaults.AWATTAR_UPDATE_HOUR:
        logger.debug(f"Not past update hour ({defaults.AWATTAR_UPDATE_HOUR}).")
        return False

    if last_update_time is not None:
        now = arrow.now()
        next_update_time = last_update_time.shift(seconds=defaults.AWATTAR_COOLDOWN_INTERVAL)
        if now < next_update_time:
            seconds_remaining = (next_update_time - now).total_seconds()
            logger.debug(f"AWATTar cooldown not finished. {seconds_remaining}s remaining.")
            return False

    midnight_tomorrow_berlin = now_berlin.floor("day").shift(days=+1)
    max_price = max(data.prices, key=lambda point: point.end_timestamp)
    max_end_time = arrow.get(max_price.end_timestamp)
    if max_end_time >= midnight_tomorrow_berlin:
        logger.debug("Price points still available until tomorrows midnight.")
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
        "start": start.int_timestamp * defaults.SEC_TO_MILLISEC,
        "end": end.int_timestamp * defaults.SEC_TO_MILLISEC,
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
    price_data.prices = BoxList()
    for raw_price_point in price_data_raw.data:
        price_point = Box()
        price_point.start_timestamp = raw_price_point.start_timestamp / defaults.SEC_TO_MILLISEC
        price_point.end_timestamp = raw_price_point.end_timestamp / defaults.SEC_TO_MILLISEC
        price_point.marketprice = raw_price_point.marketprice
        price_data.prices.append(price_point)

    return price_data


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


def transform_to_respond_data(price_data: Box) -> Box:
    """Transform price data to price data which can be sent as response from the web app.

    Do this because not all data stored should also be sent in the response.
    """
    respond_price_data = Box()
    respond_price_data.prices = price_data.prices

    return respond_price_data


async def store_data(data: Union[Box, BoxList], region: Region, config: Config):
    """Store new price data to the filesystem."""
    store_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(region.value.lower())
    file_path = store_dir / file_name

    logger.info(f"Storing aWATTar {region.value} price data to {file_path}.")
    async with async_open(file_path, "w") as file:
        await file.write(data.to_json())


async def set_last_update_time_now(region: Region, config: Config):
    """Set the time the price data was updated last to now."""
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(region.name.lower())
    file_path = file_dir / file_name

    now = arrow.now()
    now_string = str(now.int_timestamp)
    async with async_open(file_path, "w") as file:
        await file.write(now_string)


async def update_data(stored_data: Box, region: Region, config: Config):
    """Update price data when stored data was found to be outdated.

    Check the 'get_prices' docs for detailed information on the update process.

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
        # See 'get_prices' doc for a better overview and explanation of the steps.
        if immediate_acquire:
            last_update_time = await get_last_update_time(region, config)
            cooldown_finished = check_awattar_cooldown_finished(last_update_time)
            if cooldown_finished:
                downloaded_price_data_raw = await download_data(region, config)
                downloaded_price_data = general_transform_data(downloaded_price_data_raw)
                data_new = check_data_new(stored_data, downloaded_price_data)
                if data_new:
                    price_data = downloaded_price_data
                    await store_data(price_data, region, config)
                else:
                    logger.debug("Downloaded data includes no new prices.")
                    price_data = stored_data
                await set_last_update_time_now(region, config)
            else:
                logger.info("Cooldown didn't expire after rechecking it. Using stored price data.")
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
    stored_data, last_update_time = await asyncio.gather(
        get_stored_data(region, config), get_last_update_time(region, config),
        return_exceptions=True
    )
    # Need special exception handling due to concurrent execution of multiple tasks.
    if isinstance(stored_data, Exception):
        if isinstance(stored_data, JSONDecodeError):
            raise HTTPException(500)
    if isinstance(last_update_time, Exception):
        if isinstance(last_update_time, ValueError):
            raise HTTPException(500)

    do_update_data = check_update_data(stored_data, last_update_time)

    if do_update_data:
        price_data = await update_data(stored_data, region, config)
    else:
        logger.debug(f"Local price {region.name} data is still up to date.")
        price_data = stored_data

    respond_price_data = transform_to_respond_data(price_data)

    return respond_price_data
