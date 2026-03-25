"""Helpers for awattprice notifications."""
from decimal import Decimal

from awattprice.market_areas import MarketArea


def stringify_price(price: Decimal, area: MarketArea) -> str:
    """Create a string representable of a price."""
    price_string = str(price)
    if area.decimal_separator != ".":
        price_string = price_string.replace(".", area.decimal_separator)

    return price_string
