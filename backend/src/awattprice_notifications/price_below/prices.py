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
    """Describes price data about which users should be notified."""

    def __init__(self, data: Box):
        data.prices = get_notifiable_prices(data.prices)
        self.data = data


async def collect_regions_prices(config: Config, regions: list[Region]) -> Box:
    """Get the current prices for multiple regions."""
    prices_tasks = [awattprice.prices.get_current_prices(region, config) for region in regions]
    regions_prices = await asyncio.gather(*prices_tasks)
    regions_prices = dict(zip(regions, regions_prices))
    regions_prices = {region: prices for region, prices in regions_prices.items() if prices is not None}
    return regions_prices


def get_notifiable_regions_prices(regions_prices: Box):
    """Get the prices for which users should be notified for."""
    notifiable_regions_prices = {
        region: NotifiableDetailedPriceData(prices) for region, prices in regions_prices.items()
    }
    return notifiable_regions_prices
