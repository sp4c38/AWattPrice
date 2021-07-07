"""Poll and process price data."""
import asyncio
import json

from decimal import Decimal
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


def transform_from_stored_data(data: Box):
    """Transform from stored data to the app internal format."""
    for price_point in data.prices:
        price_point.marketprice = Decimal(price_point.marketprice)


def parse_to_storable_json(data: Box) -> str:
    """Parse the app interal price format to a storable json string."""
    storable_data = Box(data)
    for price_point in storable_data.prices:
        price_point.marketprice = str(price_point.marketprice)

    storable_json = storable_data.to_json()
    return storable_json


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
    except FileNotFoundError as exc:
        logger.debug(f"No stored price data found: {exc}.")
        return None

    if len(data_raw) == 0:
        return None

    try:
        data_json = json.loads(data_raw)
    except json.JSONDecodeError as exc:
        logger.exception(f"Stored price data at {file_path} no valid json: {exc}.")
        raise
    data = Box(data_json)
    # If the data is valid json assume that it is no empty dictionary or similar.
    # Validating the schema additionaly would slow down the response time unnecessarily.
    transform_from_stored_data(data)

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
        logger.debug("Price points still available until tomorrow midnight.")
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
    """Acquire the refresh lock either immediately or with waiting.

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
        logger.exception(f"Lock couldn't be acquired at all: {exc}.")
        raise
    else:
        logger.debug("Lock acquired after waiting.")
        return False


async def download_data(region: Region, config: Config) -> Optional[Box]:
    """Download price data from the aWATTar API and extract the json.

    :returns price data: As a box object.
    :returns None: If price data couldn't be downloaded or is invalid json.
    :raises json.JSONDecodeError: If response couldn't be decoded as
    """
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
        try:
            response = await client.get(url, params=url_parameters, timeout=defaults.AWATTAR_TIMEOUT)
        except httpx.RequestError as exc:
            logger.exception(f"Couldn't download price data: {exc}.")
            return None

    try:
        data_raw = response.json()
    except json.JSONDecodeError as exc:
        logger.exception(f"Couldn't decode downloaded price data as json: {exc}.")
        return None
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


def parse_downloaded_data(downloaded_data: Box) -> Box:
    """Parse the downloaded price data into the app internal format."""
    parsed_data = Box()

    parsed_data.prices = BoxList()
    for price_point in downloaded_data.data:
        formatted_price_point = Box()
        formatted_price_point.start_timestamp = price_point.start_timestamp / defaults.SEC_TO_MILLISEC
        formatted_price_point.end_timestamp = price_point.end_timestamp / defaults.SEC_TO_MILLISEC
        formatted_price_point.marketprice = Decimal(str(price_point.marketprice))
        parsed_data.prices.append(formatted_price_point)

    return parsed_data


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


async def store_data(data: Box, region: Region, config: Config):
    """Store new price data to the filesystem."""
    store_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(region.value.lower())
    file_path = store_dir / file_name

    storable_json = parse_to_storable_json(data)

    logger.info(f"Storing aWATTar {region.value} price data to {file_path}.")
    async with async_open(file_path, "w") as file:
        await file.write(storable_json)


async def get_latest_new_prices(stored_data: None, region: Region, config: Config) -> Optional[Box]:
    """Download the latest new prices.

    :returns downloaded price data: If all went well.
    :returns None: If downloaded price data isn't new or if some error occurred while getting the
        downloaded price data.
    """
    refresh_lock = get_data_refresh_lock(region, config)
    try:
        could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock)
    except filelock.Timeout as exc:
        logger.exception("Can't get latest prices because refresh lock couldn't be acquired: {exc}.")
        return None
    # See 'energy_prices.get' doc for an explanation of these update steps.
    if could_acquire_immediately:
        new_raw_data = await download_data(region, config)
        if new_raw_data is None:
            refresh_lock.release()
            return None
        try:
            await update_last_update_time(region, config)
        except Exception as exc:
            logger.exception(f"Couldn't write last update time: {exc}.")
            # Not ideal, but don't handle as it is not critical enough to justify service unavailability.
        try:
            jsonschema.validate(new_raw_data, defaults.AWATTAR_API_PRICE_DATA_SCHEMA)
        except jsonschema.ValidationError as exc:
            refresh_lock.release()
            return None
        new_data = parse_downloaded_data(new_raw_data)
        data_is_new = check_data_new(stored_data, new_data)
        if not data_is_new:
            logger.debug("Downloaded data includes no new prices.")
            refresh_lock.release()
            return None
        try:
            await store_data(new_data, region, config)
        except Exception as exc:
            # Not ideal, but still okay as this is an extra step, thus not required to get the latest new prices.
            logger.exception(f"Downloaded latest price data but couldn't store it: {exc}.")
        latest_prices = new_data
        refresh_lock.release()
    else:
        refresh_lock.release()
        latest_prices = await get_stored_data(region, config)

    return latest_prices


async def get_current_prices(region: Region, config: Config) -> Optional[dict]:
    """Get the currently up to date price data.

    This doesn't mean that this function necessarily will download the data. It could also be that stored data
    is evaluated to be the current data.

    :returns price data: When current price data could be retrieved. If local price data exists and an error
        occurred while performing other steps the function will fall back to the local price data in certain cases.
    :returns None: If there was no way to get the current price data and couldn't fall back to local data.
    """
    stored_data, last_update_time = await asyncio.gather(
        get_stored_data(region, config),
        get_last_update_time(region, config),
        return_exceptions=True,
    )
    if isinstance(stored_data, Exception):
        logger.exception(f"Couldn't get stored data: {stored_data}.")
        return None
    if isinstance(last_update_time, Exception):
        logger.exception(f"Couldn't get the last update time and thus will assume it is none: {last_update_time}.")
        last_update_time = None

    do_update_data = check_update_data(stored_data, last_update_time)
    price_data = None
    if do_update_data:
        price_data = await get_latest_new_prices(stored_data, region, config)
        if price_data is None:
            logger.debug("Local data marked as out-of-date but couldn't get new latest price data yet.")
            price_data = stored_data
    else:
        logger.debug(f"Local {region.name} prices still up to date.")
        price_data = stored_data

    return price_data


def parse_to_response_data(price_data: Box) -> Box:
    """Transform app interal format to the response format."""
    # Don't create copy to need to explicitly make data included in response opt-in.
    response_data = Box()
    response_data.prices = price_data.prices
    for price_point in response_data.prices:
        price_point.marketprice = float(price_point.marketprice)

    return response_data