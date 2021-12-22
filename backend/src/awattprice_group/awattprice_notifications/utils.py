"""Helpers for awattprice notifications."""
from decimal import Decimal

from awattprice.defaults import Region


def stringify_price(price: Decimal, region: Region) -> str:
    """Create a string representable of a price."""
    price_string = str(price)

    if region in [Region.DE, Region.AT]:
        price_string = price_string.replace(".", ",")

    return price_string
