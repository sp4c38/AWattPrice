"""Poll and process price data."""
from typing import Optional, Union

import arrow
import httpx

from box import Box, BoxList
from fastapi import HTTPException
from filelock import FileLock
from liteconfig import Config
from loguru import logger

from awattprice import defaults as dflts
from awattprice.defaults import Region
from awattprice.utils import request_url, store_file, read_json_file


async def get_stored_data(region: Region, config: Config) -> Optional[Box]:
    """Get locally stored price data."""
    file_dir = config.paths.data_dir
    file_name = dflts.PRICE_DATA_FILE_NAME.format(region.name.lower())
    file_path = file_dir / file_name

    stored_data = await read_json_file(file_path)

    return stored_data


def get_refresh_lock(region: Region, config: Config) -> FileLock:
    """"""
    lock_dir = config.paths.data_dir
    lock_file_name = dflts.PRICE_DATA_UPDATE_LOCK.formate(region.name.lower())
    lock_file_path = lock_dir / lock_file_name
    lock = FileLock(lock_file_path)
    return lock


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
        logger.debug(
            f"Won't update as there are more than {future_points_update_amount} future price points."
        )
        return False

    return True


async def get_data(region: Region, config: Config) -> Box:
    """Download current aWATTar price data.

    :raises JSONDecodeError: Raised if data returned from server can't be decoded as json.
    """
    region_config_section = f"awattar.{region.name.lower()}"
    url = getattr(config, region_config_section).url

    now = arrow.utcnow()
    # Only get prices of the current hour or later.
    start = now.replace(minute=0, second=0, microsecond=0)
    # Only get price upto the end of the following day (midnight following day).
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    end = day_start.shift(days=+2)

    url_parameters = {
        "start": start.int_timestamp * dflts.TO_MICROSECONDS,
        "end": end.int_timestamp * dflts.TO_MICROSECONDS,
    }
    timeout = dflts.AWATTAR_TIMEOUT
    logger.info(f"Getting {region.name.upper()} price data from {url}.")
    response = await request_url("GET", url, timeout=timeout, params=url_parameters)

    try:
        data_json = response.json()
    except JSONDecodeError:
        # Explicit is better than implicit.
        raise

    data = Box(data_json)

    return data


async def store_data(data: Union[Box, BoxList], region: Region, config: Config):
    """Store new price data to the filesystem."""
    store_dir = config.paths.data_dir
    file_name = dflts.PRICE_DATA_FILE_NAME.format(region.name.lower())
    file_path = store_dir / file_name

    logger.info(f"Storing aWATTar {region.name} price data to {file_path}.")
    await store_file(data.to_json(), file_path)


async def get_prices(region: Region, config: Config) -> Optional[dict]:
    """Get the current aWATTar prices.

    This manages reading, writing, updating, polling, ... of price data.
    Price data will only be polled if it isn't up to data.
    """
    refresh_lock = get_refresh_lock(config)
    await wait_not_refreshing(refresh_lock)
    stored_data = await get_stored_data(region, config)
    get_new_data = check_data_needs_update(stored_data)

    price_data = None
    if get_new_data:
        logger.info("Local energy prices aren't up to date anymore. Refreshing.")
        update_lock.acquire()
        try:
            price_data = await get_data(region, config)
        except Exception as exp:
            logger.error(f"Error when trying to get current aWATTar price data: {exp}.")
            raise HTTPException(500) from exp

        await store_data(price_data, region, config)
        update_lock.release()
    else:
        price_data = stored_data

    return price_data
