"""Poll and process price data."""
import asyncio
import json
import pickle

from copy import deepcopy
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
from liteconfig import Config
from loguru import logger

from awattprice import defaults
from awattprice import exceptions
from awattprice import utils
from awattprice.defaults import Region
from awattprice.utils import ExtendedFileLock


class MarketPrice:
    """Provide extra helper functions next to storing the marketprice."""

    value: Decimal
    region: Region

    def __init__(self, price: Decimal, region: Region):
        """Constructor for a new marketprice instance.

        :param value: Price as euro per MWh.
        :param tax: Multiplier to get the taxed price.
        """
        self.value = price
        self.region = region

    @property
    def taxed(self) -> Decimal:
        """Get the taxed price."""
        taxed_price = self.value * self.region.tax
        return taxed_price

    def ct_kwh(self, taxed: bool = False, round_: bool = False) -> Decimal:
        """Convert the price to cent per kWh.

        :param taxed: If set convert the taxed price.
        :param round: If set round the price naturally before returning.
        """
        if taxed:
            price = self.taxed
        else:
            price = self.value
        ct_kwh_price = utils.euromwh_to_ctkwh(price)

        if round_ is True:
            ct_kwh_price = utils.round_ctkwh(ct_kwh_price)

        return ct_kwh_price


async def get_stored_data(region: Region, config: Config) -> Optional[Box]:
    """Get locally cached price data.

    :returns: Price data wrapped as a Box. If file not found returns None.
    """
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(region.value.lower())
    file_path = file_dir / file_name

    try:
        async with async_open(file_path, "rb") as file:
            unpickled_data = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No stored price data found: {exc}.")
        return None

    if len(unpickled_data) == 0:
        logger.debug("Stored price data found, but is empty.")
        return None

    try:
        data = pickle.loads(unpickled_data)
        # Don't validate the schema as this would slow down the process - mostly unnecessarily.
    except pickle.UnpicklingError as exc:
        raise

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

    now_berlin = arrow.now(defaults.EUROPE_BERLIN_TIMEZONE)

    if last_update_time is not None:
        next_update_time = last_update_time.shift(seconds=defaults.AWATTAR_COOLDOWN_INTERVAL)
        if now_berlin < next_update_time:
            seconds_remaining = (next_update_time - now_berlin).total_seconds()
            logger.debug(f"AWATTar cooldown has {seconds_remaining}s remaining.")
            return False

    midnight_tomorrow_berlin = now_berlin.floor("day").shift(days=+2)
    max_price = max(data.prices, key=lambda point: point.end_timestamp)
    if max_price.end_timestamp >= midnight_tomorrow_berlin:
        logger.debug("Price points still available until tomorrow midnight.")
        return False

    if now_berlin.hour < defaults.AWATTAR_UPDATE_HOUR:
        logger.debug(f"Not past update hour ({defaults.AWATTAR_UPDATE_HOUR}).")
        return False

    return True

def get_data_refresh_lock(region: Region, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing price data."""
    lock_dir = config.paths.price_data_dir
    lock_file_name = defaults.PRICE_DATA_FILE_NAME.format(region.value.lower()) + ".lock"
    lock_file_path = lock_dir / lock_file_name
    lock = ExtendedFileLock(lock_file_path)
    return lock


async def acquire_refresh_lock_immediate(
    lock: ExtendedFileLock, timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT
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
    :returns None: If price data couldn't be downloaded or is no valid json.
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


def parse_downloaded_data(region: Region, data: Box) -> Box:
    """Parse the downloaded price data into the app internal format."""
    new_data = Box()
    new_data.prices = BoxList()
    for point in data.data:
        new_point = Box()
        start_timestamp = point.start_timestamp / defaults.SEC_TO_MILLISEC
        new_point.start_timestamp = arrow.get(start_timestamp).to(defaults.EUROPE_BERLIN_TIMEZONE)
        end_timestamp = point.end_timestamp / defaults.SEC_TO_MILLISEC
        new_point.end_timestamp = arrow.get(end_timestamp).to(defaults.EUROPE_BERLIN_TIMEZONE)
        marketprice = Decimal(str(point.marketprice))
        new_point.marketprice = MarketPrice(marketprice, region)
        new_data.prices.append(new_point)

    return new_data


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

    pickled_data = pickle.dumps(data)

    logger.info(f"Storing aWATTar {region.value} price data to {file_path}.")
    async with async_open(file_path, "wb") as file:
        await file.write(pickled_data)


async def get_latest_new_prices(stored_data: None, region: Region, config: Config) -> Optional[Box]:
    """Download the latest new prices.

    :returns downloaded price data: If all went well.
    :returns None: There are no latest new prices.
    """
    refresh_lock = get_data_refresh_lock(region, config)
    could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock)

    # See 'energy_prices.get' doc for an explanation of these update steps.
    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            new_data = await download_data(region, config)
            if new_data is None:
                return None
            try:
                await update_last_update_time(region, config)
            except Exception as exc:
                logger.exception(f"Couldn't write last update time: {exc}.")
                # Not ideal, but also not essential to provide the latest new prices.
            jsonschema.validate(new_data, defaults.AWATTAR_API_PRICE_DATA_SCHEMA)
            new_data = parse_downloaded_data(region, new_data)
            data_is_new = check_data_new(stored_data, new_data)
            if not data_is_new:
                logger.debug("Downloaded data includes no new prices.")
                return None
            await store_data(new_data, region, config)
            latest_prices = new_data
    else:
        refresh_lock.release()
        latest_prices = await get_stored_data(region, config)

    return latest_prices


async def get_current_prices(region: Region, config: Config, fall_back=False) -> Optional[dict]:
    """Get the currently up to date price data.

    :param fall_back: If true function will fall back to the stored data in certain situations when an
        error retrieving the actual current prices occurrs. If false none will be returned in such cases.
    """
    stored_data, last_update_time = await asyncio.gather(
        get_stored_data(region, config),
        get_last_update_time(region, config),
        return_exceptions=True,
    )
    if isinstance(stored_data, Exception):
        logger.exception(f"Couldn't get stored {region.name} data: {stored_data}.")
        return None
    if isinstance(last_update_time, Exception):
        logger.exception(
            f"Couldn't get the {region.name} last update time and thus will assume it is none: {last_update_time}."
        )
        last_update_time = None

    do_update_data = check_update_data(stored_data, last_update_time)
    price_data = None
    if do_update_data:
        try:
            price_data = await get_latest_new_prices(stored_data, region, config)
        except Exception as exc:
            logger.exception(f"Couldn't get latest new {region.name} prices: {exc}.")
            if not fall_back: return None
            price_data = stored_data
        else:
            if price_data is None:
                logger.warning(f"No latest new {region.name} prices.")
                if not fall_back: return None
                price_data = stored_data
    else:
        logger.debug(f"Local {region.name} prices still up to date.")
        price_data = stored_data

    return price_data


def parse_to_response_data(price_data: Box) -> Box:
    """Parse app interal format to the response format."""
    # Don't create copy to need to explicitly make data included in response opt-in.
    response_data = Box()
    response_data.prices = []
    for price_point in price_data.prices:
        response_point = Box()
        response_point.start_timestamp = price_point.start_timestamp.int_timestamp
        response_point.end_timestamp = price_point.end_timestamp.int_timestamp
        response_point.marketprice = float(price_point.marketprice.value)
        response_data.prices.append(response_point)

    return response_data
