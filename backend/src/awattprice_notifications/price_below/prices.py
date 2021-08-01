"""Manage and handle price data fron the main awattprice package."""
import asyncio

from decimal import Decimal
from typing import Optional

import awattprice

from arrow import Arrow
from awattprice.defaults import Region
from box import Box
from liteconfig import Config
from loguru import logger

from awattprice_notifications.price_below.defaults import get_notifiable_prices


class DetailedPriceData:
    """Describes price data in a detailed manner."""

    data: Box

    lowest_price: Optional[Box] = None

    def __init__(self, data: Box):
        self.data = data

    def find_lowest_price(self):
        """Find the lowest price."""
        lowest_price = min(self.data.prices, key=lambda price_point: price_point.marketprice.value)
        self.lowest_price = lowest_price

    def get_prices_below_value(self, below_value: Decimal, taxed: bool) -> list[int]:
        """Get prices which are on or below the given value.

        :param taxed: If true prices are taxed before comparing to the below value. This doesn't affect the
            below value.
        """
        below_value_prices = []
        for price_point in self.data.prices:
            marketprice = price_point.marketprice.ct_kwh(taxed=taxed, round_=True)
            if marketprice <= below_value:
                below_value_prices.append(price_point)

        return below_value_prices


class NotifiableDetailedPriceData(DetailedPriceData):
    """Holds price data about which users should be notified for."""

    def __init__(self, notifiable_data: Box):
        self.data = notifiable_data


async def collect_regions_prices(config: Config, regions: list[Region]) -> Box:
    """Get the current prices for multiple regions."""
    prices_tasks = [awattprice.prices.get_current_prices(region, config, fall_back=False) for region in regions]
    regions_prices = await asyncio.gather(*prices_tasks)
    regions_prices = dict(zip(regions, regions_prices))

    existing_regions_prices = {}
    for region, prices in regions_prices.items():
        if prices is None:
            logger.warning(f"Couldn't get current price data for region {region}.")
            continue
        existing_regions_prices[region] = prices

    return existing_regions_prices


def get_notifiable_regions_prices(regions_prices: Box) -> Box:
    """Get the prices for which users should be notified for."""
    notifiable_regions_prices = Box()
    for region, prices_data in regions_prices.items():
        notifiable_prices_data = prices_data
        notifiable_prices = get_notifiable_prices(prices_data.prices)
        if len(notifiable_prices) == 0:
            logger.debug(f"No notifiable prices for region {region}.")
            continue
        notifiable_prices_data.prices = notifiable_prices
        notifiable_detailed_prices = NotifiableDetailedPriceData(notifiable_prices_data)
        notifiable_regions_prices[region] = notifiable_detailed_prices

    return notifiable_regions_prices
