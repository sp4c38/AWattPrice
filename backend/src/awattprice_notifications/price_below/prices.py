"""Manage and handle price data fron the main awattprice package."""
import asyncio

import awattprice

from awattprice.defaults import Region
from box import Box
from liteconfig import Config
from loguru import logger


async def collect_regions_data(config: Config, regions: list[Region]) -> Box:
    """Get the current prices for multiple regions."""
    prices_tasks = [awattprice.prices.get_current_prices(region, config) for region in regions]
    all_prices = await asyncio.gather(*prices_tasks)
    all_prices = dict(zip(regions, all_prices))

    valid_prices = {}
    for region, prices in all_prices:
        if prices is None:
            logger.warning(f"No current price data for region {region.name}")
            continue
        valid_prices[region] = prices

    return valid_prices
