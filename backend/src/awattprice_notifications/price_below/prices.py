"""Manage and handle price data fron the main awattprice package."""
import asyncio

import awattprice

from awattprice.defaults import Region
from box import Box
from liteconfig import Config
from loguru import logger

from awattprice_notifications.price_below.defaults import DetailedPriceData


async def collect_regions_data(config: Config, regions: list[Region]) -> Box:
    """Get the current prices for multiple regions."""
    prices_tasks = [awattprice.prices.get_current_prices(region, config) for region in regions]
    regions_prices = await asyncio.gather(*prices_tasks)
    regions_prices = dict(zip(regions, regions_prices))

    valid_regions_prices = {}
    for region, prices in regions_prices.items():
        if prices is None:
            logger.warning(f"No current price data for region {region.name}. Skipping it.")
            continue
        valid_regions_prices[region] = prices

    detailed_regions_prices = {
        region: DetailedPriceData(data=prices) for region, prices in valid_regions_prices.items()
    }

    return detailed_regions_prices
