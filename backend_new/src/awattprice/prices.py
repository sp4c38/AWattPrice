"""Poll and process price data."""
from typing import Optional

import arrow
import httpx

from box import BoxList
from fastapi import HTTPException
from liteconfig import Config
from loguru import logger

from awattprice.defaults import AWATTAR_TIMEOUT, Region, TO_MICROSECONDS


async def poll_price_data(url: str, from_time: arrow.Arrow, to_time: arrow.Arrow) -> Optional[BoxList]:
    """Download aWATTar price data.

    :throws: May throws errors like JSONDecodeError if any errors occurs during download and processing.
    """
    url_parameters = {
        "start": from_time.int_timestamp * TO_MICROSECONDS,
        "end": to_time.int_timestamp * TO_MICROSECONDS,
    }
    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=url_parameters, timeout=AWATTAR_TIMEOUT)

    all_data_json = response.json()
    data_json = all_data_json["data"]
    data = BoxList(data_json)

    return data


async def get_price_data(region: Region, config: Config) -> Optional[BoxList]:
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

    data = await poll_price_data(url, start, end)

    return data


async def get_prices(region: Region, config: Config) -> Optional[dict]:
    """Get the current aWATTar prices.

    This manages reading, writing, updating, polling, ... of price data.
    Price data will only be polled if it isn't upto date - which mostly isn't the case.
    """
    try:
        price_data = await get_price_data(region, config)
    except Exception as exp:
        logger.error(f"Error when trying to get current aWATTar price data: {exp}.")
        raise HTTPException(500) from exp

    return price_data
