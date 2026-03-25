"""Supported ENTSO-E market areas."""
from dataclasses import dataclass
from decimal import Decimal
from typing import Optional


@dataclass(frozen=True)
class MarketArea:
    """Describe a supported market area."""

    key: str
    entsoe_domain: str
    display_name: str
    country_code: str
    timezone: str
    tax_multiplier: Optional[Decimal]
    currency: str = "EUR"
    price_measurement_unit: str = "MWH"
    subunits_per_currency_unit: int = 100
    decimal_separator: str = ","
    preferred_price_sequence: Optional[int] = 1


SUPPORTED_MARKET_AREAS = {
    "DE-LU": MarketArea(
        key="DE-LU",
        entsoe_domain="10Y1001A1001A82H",
        display_name="Germany / Luxembourg",
        country_code="DE",
        timezone="Europe/Berlin",
        tax_multiplier=Decimal("1.19"),
        preferred_price_sequence=1,
    ),
    "AT": MarketArea(
        key="AT",
        entsoe_domain="10YAT-APG------L",
        display_name="Austria",
        country_code="AT",
        timezone="Europe/Vienna",
        tax_multiplier=Decimal("1.20"),
        preferred_price_sequence=1,
    ),
}

DEFAULT_MARKET_AREA_KEY = "DE-LU"


def normalize_market_area_key(value: str) -> str:
    """Normalize external market-area keys."""
    return value.strip().upper().replace("_", "-")


def get_market_area(area_key: str) -> MarketArea:
    """Get a supported market area by key."""
    normalized_key = normalize_market_area_key(area_key)
    return SUPPORTED_MARKET_AREAS[normalized_key]


def list_market_areas() -> list[MarketArea]:
    """Return supported market areas in declaration order."""
    return list(SUPPORTED_MARKET_AREAS.values())
