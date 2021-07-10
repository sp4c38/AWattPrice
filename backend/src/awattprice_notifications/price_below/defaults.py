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
    lowest_price_index: Optional[int] = None  # Index to the lowest price point in the price data.

    def set_lowest_price(self):
        """Find the lowest price and set the objects attribute to this price points index."""
        prices = self.data.prices
        lowest_price = min(enumerate(prices), key=lambda price_point: price_point[1].marketprice)
        lowest_price_index = lowest_price[0]
        self.lowest_price_index = lowest_price_index


# Regions for which to send price below notifications.
REGIONS_TO_SEND = [Region.DE, Region.AT]
