"""Poll and process price data."""
from typing import Optional

import arrow
import httpx

from box import BoxList
from fastapi import HTTPException
from liteconfig import Config
from loguru import logger

from awattprice import defaults as dflts
from awattprice.defaults import Region
from awattprice.utils import lock_store_file, read_json_file


async def get_stored_data(region: Region, config: Config) -> Optional[BoxList]:
    """Get locally stored price data."""
    file_dir = config.paths.data_dir
    file_name = dflts.PRICE_DATA_FILE_NAME.format(region.name.lower())
    file_path = file_dir / file_name

    stored_data_raw = await read_json_file(file_path)
    if stored_data_raw is None:
        return None
    stored_data = BoxList(stored_data_raw)
    return stored_data


def check_data_needs_update(data: Box) -> bool:
    """Check if price data is up to date.

    :returns: True if up to date, false if not.
    """
    needs_update = True
    now = arrow.now()
    from_timestamp = data.meta.from_timestamp
    if from_timestamp + dflts.AWATTAR_REFRESH_INTERVAL > now.int_timestamp:
        return False

    amount_future_points = len([p for p in data.prices if p.start_timestamp > now.timestamp])
    if amount_future_points > 12:
        needs_update = False

    return needs_update


async def download_data(url: str, from_time: arrow.Arrow, to_time: arrow.Arrow) -> Optional[BoxList]:
    """Download aWATTar price data.

    :throws: May throws errors like JSONDecodeError if any errors occurs during download and processing.
    """
    url_parameters = {
        "start": from_time.int_timestamp * dflts.TO_MICROSECONDS,
        "end": to_time.int_timestamp * dflts.TO_MICROSECONDS,
    }
    async with httpx.AsyncClient() as client:
        logger.debug(f"Downloading aWATTar price data from {url}.")
        response = await client.get(url, params=url_parameters, timeout=dflts.AWATTAR_TIMEOUT)

    all_data_json = response.json()
    data_json = all_data_json["data"]
    data = BoxList(data_json)

    return data


async def get_data(region: Region, config: Config) -> Optional[BoxList]:
    """Get aWATTar price data.

    This gets certain parameters for the download. It won't do the actual downloading.

    :returns: Price data if it could be downloaded successfully.
    :throws: May throws any error if download and processing is unsuccessful.
    """
    region_config_section = f"awattar.{region.name.lower()}"
    url = getattr(config, region_config_section).url

    now = arrow.utcnow()
    # Only get prices of the current hour or later.
    start = now.replace(minute=0, second=0, microsecond=0)
    # Only get price upto the end of the following day (midnight following day).
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    end = day_start.shift(days=+2)

    logger.info(f"Getting price data for region {region.name}.")
    data = await download_data(url, start, end)

    return data


async def store_data(data: BoxList, region: Region, config: Config):
    store_dir = config.paths.data_dir
    file_name = dflts.PRICE_DATA_FILE_NAME.format(region.name.lower())
    file_path = store_dir / file_name

    logger.info(f"Storing aWATTar {region.name} price data to {file_path}.")
    await lock_store_file(data.to_json(), file_path)


async def get_prices(region: Region, config: Config) -> Optional[dict]:
    """Get the current aWATTar prices.

    This manages reading, writing, updating, polling, ... of price data.
    Price data will only be polled if it isn't up to data.
    """
    stored_data = await get_stored_data(region, config)
    get_new_data = check_data_needs_update(stored_data)

    if get_new_data:
        logger.info("Local energy prices aren't up to date anymore. Refreshing.")
        try:
            price_data = await get_data(region, config)
        except Exception as exp:
            logger.error(f"Error when trying to get current aWATTar price data: {exp}.")
            raise HTTPException(500) from exp

        store_data(price_data, region, config)

    return price_data
