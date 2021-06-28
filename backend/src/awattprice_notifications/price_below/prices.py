"""Manage and handle price data fron the main awattprice package."""
from box import Box
from liteconfig import Config
from loguru import logger

from awattprice import prices
from awattprice.defaults import Region


async def collect_multiple_region_prices(regions: list[Region], config: Config) -> Box:
    """Get the current prices for multiple regions."""
    regions_data = Box()
    for region in regions:
        price_data = await prices.get_current_prices(region, config)

        if price_data is None:
            logger.warning(f"No current price data for region {region.name}.")
            continue

        regions_data[region] = price_data

    return regions_data
