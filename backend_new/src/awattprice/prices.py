"""Poll and process price data."""
import json

from typing import Optional, Union

import arrow
import filelock
import httpx

from box import Box, BoxList
from fastapi import HTTPException
from filelock import FileLock
from liteconfig import Config
from loguru import logger

from awattprice import defaults as dflts
from awattprice import exceptions as exc
from awattprice import utils
from awattprice.defaults import Region


def get_refresh_lock(region: Region, config: Config) -> FileLock:
    """Get file lock used when refreshing price data."""
    lock_dir = config.paths.data_dir
    lock_file_name = dflts.PRICE_DATA_REFRESH_LOCK.formate(region.name.lower())
    lock_file_path = lock_dir / lock_file_name
    lock = FileLock(lock_file_path)
    return lock


async def immediate_refresh_lock_acquire(lock, keep_acquired=True) -> bool:
    """Acquire a refresh lock either immediately or with waiting.

    :param keep_acquired: Default is true. Set if the lock should be kept acquired when returning.
        If set to false this function more acts as a checker if the lock could be acquired. Note that in
        this case the lock could be immediately acquired after returning, making the return invalid/unsafe.
        Using false this function should only be used when it is okay that the return may be invalid in the
        very next moment.

    :raises filelock.Timeout: if the refresh token lock acquiring timed out.
    :returns: Returns as soon as the lock was acquired. Returns true if lock was acquired immediately
        and false if function had to wait until lock could be acquired.
    """
    async_acquire = utils.async_wrap(lock.acquire)
    async_release = utils.async_wrap(lock.release)
    timeout = dflts.PRICE_DATA_REFRESH_LOCK_TIMEOUT

    # Check for immediate acquirement.
    try:
        await async_acquire(timeout=0)
    except filelock.Timeout:
        # Means that lock couldn't be acquired immediately.
        pass
    else:
        logger.debug("Lock acquired immediately.")
        if not keep_acquired:
            await async_release()
        return True

    try:
        await async_acquire(timeout=timeout)
    except filelock.Timeout as exp:
        logger.info(f"Lock couldn't be acquired at all: {exp}.")
        raise
    else:
        logger.debug("Lock acquired after waiting.")
        if not keep_acquired:
            await async_release()

    return False


async def get_stored_data(region: Region, config: Config) -> Optional[Box]:
    """Get locally stored price data."""
    file_dir = config.paths.data_dir
    file_name = dflts.PRICE_DATA_FILE_NAME.format(region.name.lower())
    file_path = file_dir / file_name

    stored_data = await utils.read_json_file(file_path)

    return stored_data


def check_data_needs_update(data: Box) -> bool:
    """Check if price data is up to date.

    :returns: True if up to date, false if not.
    """
    now = arrow.now()
    next_refresh_time = data.meta.from_timestamp + dflts.AWATTAR_REFRESH_INTERVAL
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
        end_timestamp = point.end_timestamp / dflts.TO_MICROSECONDS
        if end_timestamp > now.int_timestamp:
            amount_future_points += 1
    # Update if the amount of future price points is smaller or equal to this amount.
    future_points_update_amount = 24 - dflts.AWATTAR_UPDATE_HOUR
    if amount_future_points <= future_points_update_amount:
        pass
    else:
        logger.debug(f"Won't update as there are more than {future_points_update_amount} future price points.")
        return False

    return True


async def get_data(region: Region, config: Config) -> Box:
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
        "start": start.int_timestamp * dflts.TO_MICROSECONDS,
        "end": end.int_timestamp * dflts.TO_MICROSECONDS,
    }
    timeout = dflts.AWATTAR_TIMEOUT

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
        raise HTTPException(500)

    data = Box(data_json)

    return data


async def store_data(data: Union[Box, BoxList], region: Region, config: Config):
    """Store new price data to the filesystem."""
    store_dir = config.paths.data_dir
    file_name = dflts.PRICE_DATA_FILE_NAME.format(region.name.lower())
    file_path = store_dir / file_name

    logger.info(f"Storing aWATTar {region.name} price data to {file_path}.")
    await utils.store_file(data.to_json(), file_path)


async def get_new_prices(refresh_lock: FileLock, region: Region, config: Config) -> Optional[Box]:
    """Get new aWATTar price data."""
    try:
        immediate_acquire = await immediate_refresh_lock_acquire(refresh_lock)
    except filelock.Timeout:
        raise exc.RefreshLockAcquireError()

    price_data = None
    if not immediate_acquire:
        price_data = await get_data(region, config)
        await store_data(price_data, region, config)
        refresh_lock.release()
    else:
        pass


async def get_current_prices(region: Region, config: Config) -> Optional[dict]:
    """Get the current aWATTar prices.

    Current aWATTar prices may either be local or remote data.
    Remote data will be fetched if local data isn't up to date.
    """
    stored_data = await get_stored_data(region, config)
    get_new_data = check_data_needs_update(stored_data)

    price_data = None
    if get_new_data:
        refresh_lock = get_refresh_lock(config)
        logger.info("Local energy prices aren't up to date anymore. Refreshing.")
        try:
            price_data = await get_new_prices(refresh_lock, region, config)
        except exc.RefreshLockAquireError:
            if not stored_data:
                logger.error(
                    "Refresh lock couldn't be acquired and no local data is available. Returning 500 error."
                )
                raise HTTPException(500)

            logger.info("Using local stored data because refresh lock couldn't be acquired.")
            price_data = stored_data
    else:
        logger.debug("Local price data still up to date.")
        price_data = stored_data

    return price_data
