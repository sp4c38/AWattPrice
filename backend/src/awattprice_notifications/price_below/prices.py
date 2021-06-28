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
        try:
            price_data = await prices.get_current_prices(region, config)
        except Exception as exc:
            logger.exception(f"Couldn't get current prices for region {region.name}: {exc}.")
            continue

        if price_data is None:
            logger.warning(f"No current price data for region {region.name}.")
            continue

        regions_data[region] = price_data

    return regions_data
