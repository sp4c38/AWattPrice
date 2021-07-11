"""Manage and handle price data fron the main awattprice package."""
import asyncio

from dataclasses import dataclass
from decimal import Decimal
from typing import Optional

import awattprice

from awattprice.defaults import Region
from box import Box
from liteconfig import Config
from loguru import logger


@dataclass
class DetailedPriceData:
    """Store extra information in addition to the region price data to describe it in more detail."""

    data: Box
    lowest_price_index: Optional[int] = None  # Index to the lowest price point in the price data.

    def set_lowest_price(self):
        """Find the lowest price and set the objects attribute to this price points index."""
        prices = self.data.prices
        lowest_price = min(enumerate(prices), key=lambda price_point: price_point[1].marketprice)
        lowest_price_index = lowest_price[0]
        self.lowest_price_index = lowest_price_index


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
