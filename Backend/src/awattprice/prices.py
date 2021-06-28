"""Poll and process price data."""
import asyncio
import json

from typing import Optional
from typing import Union

import arrow
import filelock
import httpx
import jsonschema

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

    if len(data_raw) == 0:
        return None

    try:
        data_json = json.loads(data_raw)
    except json.JSONDecodeError as exc:
        logger.exception(f"Stored price data no valid json: {file_path}.")
        raise
    data = Box(data_json)

    # If the data is valid json assume that it is no empty dictionary or similar.
    # Validating the schema additionaly would mostly slow down the response time unnecessarily.

    return data


async def get_last_update_time(region: Region, config: Config) -> Optional[Arrow]:
    """Get time the price data was updated last.

    :returns None: If file not found.
    :returns arrow.Arrow: Last update time. 
    """
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(region.name.lower())
    file_path = file_dir / file_name

    try:
        async with async_open(file_path, "r") as file:
            file_content = await file.read()
    except FileNotFoundError:
        return None

    timestamp = int(file_content)
    time = arrow.get(timestamp)

    return time


def check_update_data(data: Optional[Box], last_update_time: Optional[Arrow]) -> bool:
    """Check if price data is due for update.

    :param last_update_time: Time data was last polled from the awattar api.
    :returns: True if data is due, false if not due.
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


def get_data_refresh_lock(region: Region, config: Config) -> FileLock:
    """Get file lock used when refreshing price data."""
    lock_dir = config.paths.price_data_dir
    lock_file_name = defaults.PRICE_DATA_FILE_NAME.format(region.value.lower())
    lock_file_path = lock_dir / lock_file_name
    lock = FileLock(lock_file_path)
    return lock


async def acquire_refresh_lock_immediate(
    lock: FileLock, timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT
) -> bool:
    """Acquire a refresh lock either immediately or with waiting.

    :returns: As soon as lock was acquired.
    :returns True: Acquired lock immediately.
    :returns False: Acquired lock after waiting.
    :raises filelock.Timeout: Lock couldn't be acquired - even after waiting.
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
    """Download price data from the aWATTar API."""
    region_config_identifier = f"awattar.{region.value.lower()}"
    url = getattr(config, region_config_identifier).url

    now = arrow.utcnow()
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    start = now.replace(minute=0, second=0, microsecond=0)
    end = day_start.shift(days=+2)

    url_parameters = {
        "start": start.int_timestamp * defaults.SEC_TO_MILLISEC,
        "end": end.int_timestamp * defaults.SEC_TO_MILLISEC,
    }
    logger.info(f"Polling {region.value.upper()} price data from {url}.")
    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=url_parameters, timeout=defaults.AWATTAR_TIMEOUT)

    data_raw = response.json()
    data = Box(data_raw)

    return data


async def update_last_update_time(region: Region, config: Config):
    """Set the time the price data was updated last to the current time."""
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(region.name.lower())
    file_path = file_dir / file_name

    now = arrow.now()
    now_string = str(now.int_timestamp)
    async with async_open(file_path, "w") as file:
        await file.write(now_string)


def transform_downloaded_data(downloaded_data: Box) -> Box:
    """Transform downloaded price data into app internal format.

    It may be required to perform extended transformations in specific cases.
    """
    formatted_data = Box()

    formatted_data.prices = BoxList()
    for price_point in downloaded_data.data:
        formatted_price_point = Box()
        formatted_price_point.start_timestamp = price_point.start_timestamp / defaults.SEC_TO_MILLISEC
        formatted_price_point.end_timestamp = price_point.end_timestamp / defaults.SEC_TO_MILLISEC
        formatted_price_point.marketprice = price_point.marketprice
        formatted_data.prices.append(formatted_price_point)

    return formatted_data


def check_data_new(old_data: Optional[Box], new_data: Box) -> bool:
    """Check if new price points were added relative to the max price point of the old price data."""
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


async def get_latest_new_prices(stored_data: None, region: Region, config: Config) -> Box:
    """Get the latest price data if the local data was found to be out-of-date.

    :returns price data: If everything went well. May be remote prices, may be local prices - depends.
    :returns None: If no latest data. For example latest data is stored data but stored data is already None.
    """
    refresh_lock = get_data_refresh_lock(region, config)
    could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock)
    # See 'energy_prices.get' doc for an explanation of these update steps.
    if could_acquire_immediately:
        new_data_raw = await download_data(region, config)
        await update_last_update_time(region, config)
        try:
            jsonschema.validate(new_data_raw, defaults.AWATTAR_API_PRICE_DATA_SCHEMA)
        except jsonschema.ValidationError as exc:
            logger.exception(f"Polled aWATTar data doesn't conform to the required schema: {exc}.")
            refresh_lock.release()
            return stored_data
        new_data = transform_downloaded_data(new_data_raw)
        data_is_new = check_data_new(stored_data, new_data)
        if data_is_new:
            try:
                await store_data(new_data, region, config)
            except Exception as exc:
                refresh_lock.release()
                raise
            latest_prices = new_data
        else:
            logger.debug("Downloaded data includes no new prices.")
            latest_prices = stored_data
        refresh_lock.release()
    else:
        refresh_lock.release()
        latest_prices = await get_stored_data(region, config)

    return latest_prices


def transform_to_response_data(price_data: Box) -> Box:
    """Transform internally used price data to price data for responses."""
    # Using this approach data included in response is opt-in and not the worser opt-out.
    response_data = Box()
    response_data.prices = price_data.prices

    return response_data


async def get_current_prices(region: Region, config: Config) -> Optional[dict]:
    """Get the current aWATTar prices.

    Current aWATTar prices may either be local or remote data.
    Remote data will be fetched if local data isn't up to date.
    """
    stored_data, last_update_time = await asyncio.gather(
        get_stored_data(region, config), get_last_update_time(region, config)
    )

    do_update_data = check_update_data(stored_data, last_update_time)
    price_data = None
    if do_update_data:
        price_data = await get_latest_new_prices(stored_data, region, config)
    else:
        logger.debug(f"Local {region.name} prices still up to date.")
        price_data = stored_data

    return price_data
