"""Default values and models for the price below notification service."""
from dataclasses import dataclass
from decimal import Decimal
from typing import Optional

from awattprice.defaults import Region
from box import Box


@dataclass
class DetailedPriceData:
    """Store extra information in addition to the region price data to describe it in more detail."""

    data: Box
    lowest_price: Optional[Box] = None

    def set_lowest_price(self):
    	"""Find the lowest price and set the objects attribute to the price_point."""
    	prices = self.data.prices
    	lowest_price = min(prices, key=lambda price_point: price_point.marketprice)
    	self.lowest_price = lowest_price


# Regions for which to send price below notifications.
REGIONS_TO_SEND = [Region.DE, Region.AT]
