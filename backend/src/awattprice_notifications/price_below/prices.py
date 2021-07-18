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
    lowest_price: Optional[Box] = None

    def set_lowest_price(self):
        """Find the lowest price and set the objects attribute to this price point."""
        prices = self.data.prices
        lowest_price = min(prices, key=lambda price_point: price_point.marketprice)
        self.lowest_price = lowest_price

    def get_prices_below_value(self, below_value: Decimal, tax: Optional[Decimal]) -> list[int]:
        """Get prices which are on or below a given value.

        :param tax: Optional tax calculated onto the prices before checking. Below value stays unchanged.
        """
        below_value_prices = []
        for price_point in self.data:
            marketprice = price_point.marketprice
            if tax is not None:
                marketprice *= tax
            if marketprice <= below_value:
                below_value_prices.append(price_point)

        return below_value_prices



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
