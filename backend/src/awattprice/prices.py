"""Poll and process price data."""
import pickle

from datetime import date
from decimal import Decimal
from typing import Optional

import arrow

from aiofile import async_open
from arrow import Arrow
from box import Box
from liteconfig import Config
from loguru import logger

from awattprice import defaults
from awattprice import utils
from awattprice.market_areas import MarketArea


class MarketPrice:
    """Provide extra helper functions next to storing the marketprice."""

    value: Decimal
    area: MarketArea

    def __init__(self, price: Decimal, area: MarketArea):
        """Constructor for a new marketprice instance.

        :param value: Price as euro per MWh.
        :param tax: Multiplier to get the taxed price.
        """
        self.value = price
        self.area = area

    @property
    def taxed(self) -> Decimal:
        """Get the taxed price."""
        if self.area.tax_multiplier is not None:
            return self.value * self.area.tax_multiplier
        else:
            return self.value

    def subunit_kwh(self, taxed: bool = False, round_: bool = False) -> Decimal:
        """Convert the price to currency subunits per kWh.

        :param taxed: If set convert the taxed price.
        :param round_: If set round the price naturally before returning.
        """
        if taxed:
            price = self.taxed
        else:
            price = self.value
        subunit_kwh_price = utils.unitmwh_to_subunitkwh(price, self.area.subunits_per_currency_unit)

        if round_ is True:
            subunit_kwh_price = utils.round_subunitkwh(subunit_kwh_price)

        return subunit_kwh_price


def area_file_key(area_key: str) -> str:
    """Get a filesystem-friendly area key."""
    return defaults.normalize_market_area_key(area_key).lower().replace("-", "_").replace("(", "_").replace(")", "")


def history_date_file_key(day: date) -> str:
    """Get a filesystem-friendly history date key."""
    return day.isoformat()


def resolution_to_seconds(resolution: str) -> int:
    """Convert a simple ISO8601 ENTSO-E duration to seconds."""
    resolution_mapping = {
        "PT15M": 15 * 60,
        "PT30M": 30 * 60,
        "PT60M": 60 * 60,
    }
    return resolution_mapping[resolution]


async def get_stored_data(area_key: str, config: Config) -> Optional[Box]:
    """Get locally cached price data.

    :returns: Price data wrapped as a Box. If file not found returns None.
    """
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(area_file_key(area_key))
    file_path = file_dir / file_name

    try:
        async with async_open(file_path, "rb") as file:
            unpickled_data = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No stored price data found: {exc}.")
        return None

    if len(unpickled_data) == 0:
        logger.debug("Stored price data found, but is empty.")
        return None

    data = pickle.loads(unpickled_data)
    if len(data.prices) == 0:
        logger.debug(f"Stored {area_key} price data found, but includes no prices.")
        return None

    return data


def has_current_price_points(data: Optional[Box], area: MarketArea) -> bool:
    """Check if cached data contains prices the app can still display."""
    if data is None:
        return False

    now_local = arrow.now(area.timezone)
    return any(price_point.end_timestamp > now_local for price_point in data.prices)


def validate_history_date(area: MarketArea, day: date) -> bool:
    """Return true when day is a completed historical local day."""
    yesterday = arrow.now(area.timezone).floor("day").shift(days=-1).date()
    return day <= yesterday


def _price_point_signature(price_point: Box) -> tuple[int, int, str, Optional[str], bool]:
    return (
        price_point.start_timestamp.int_timestamp,
        price_point.end_timestamp.int_timestamp,
        str(price_point.marketprice.value),
        price_point.get("sequence_position"),
        bool(price_point.get("is_fallback", False)),
    )


def price_data_signature(price_data: Box) -> tuple[tuple[int, int, str, Optional[str], bool], ...]:
    """Build a stable signature for comparing cached price payloads."""
    return tuple(sorted(_price_point_signature(price_point) for price_point in price_data.prices))


def unique_price_point_count(price_data: Box) -> int:
    """Count unique start timestamps in a price payload."""
    return len({price_point.start_timestamp.int_timestamp for price_point in price_data.prices})


def fallback_price_count(price_data: Box) -> int:
    """Count prices that were filled from a non-primary sequence."""
    return sum(1 for price_point in price_data.prices if price_point.get("is_fallback", False))


def has_complete_price_points(price_data: Optional[Box], period_start: Arrow, period_end: Arrow) -> bool:
    """Return true when a price payload contains every expected interval in a period."""
    if price_data is None or not price_data.prices or price_data.resolution is None:
        return False

    interval_seconds = resolution_to_seconds(price_data.resolution)
    expected_count = int((period_end.int_timestamp - period_start.int_timestamp) / interval_seconds)
    expected_starts = {
        period_start.int_timestamp + interval_seconds * index
        for index in range(expected_count)
    }
    actual_starts = {
        price_point.start_timestamp.int_timestamp
        for price_point in price_data.prices
        if (
            price_point.start_timestamp.int_timestamp >= period_start.int_timestamp
            and price_point.end_timestamp.int_timestamp <= period_end.int_timestamp
        )
    }

    return actual_starts == expected_starts


def has_complete_local_day(price_data: Optional[Box], area: MarketArea, day: date) -> bool:
    """Return true when a price payload contains every interval for a local market day."""
    period_start = arrow.get(day.isoformat(), "YYYY-MM-DD", tzinfo=area.timezone)
    return has_complete_price_points(price_data, period_start, period_start.shift(days=+1))


def complete_tomorrow_prices(price_data: Optional[Box], area: MarketArea, now=None) -> bool:
    """Return true when a price payload contains all prices for the next local day."""
    if price_data is None:
        return False
    current = now or arrow.now(area.timezone)
    tomorrow_start = current.to(area.timezone).floor("day").shift(days=+1)
    tomorrow_end = tomorrow_start.shift(days=+1)
    return has_complete_price_points(price_data, tomorrow_start, tomorrow_end)


async def store_data(data: Box, area_key: str, config: Config):
    """Store new price data to the filesystem."""
    file_name = defaults.PRICE_DATA_FILE_NAME.format(area_file_key(area_key))
    file_path = config.paths.price_data_dir / file_name

    pickled_data = pickle.dumps(data)

    logger.info(f"Storing ENTSO-E {area_key} price data to {file_path}.")
    await utils.async_atomic_write_bytes(file_path, pickled_data)


def get_history_data_dir(config: Config):
    """Get the directory used for immutable historical price caches."""
    return config.paths.price_data_dir / defaults.PRICE_HISTORY_DATA_SUBDIR_NAME


def get_history_data_path(area_key: str, day: date, config: Config):
    """Get the cache path for one market area and historical day."""
    file_name = defaults.PRICE_DATA_FILE_NAME.format(
        f"{area_file_key(area_key)}-{history_date_file_key(day)}"
    )
    return get_history_data_dir(config) / file_name


async def get_stored_history_data(area_key: str, day: date, config: Config) -> Optional[Box]:
    """Get cached historical price data."""
    file_path = get_history_data_path(area_key, day, config)

    try:
        async with async_open(file_path, "rb") as file:
            unpickled_data = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No stored historical price data found: {exc}.")
        return None

    if len(unpickled_data) == 0:
        return None

    data = pickle.loads(unpickled_data)
    if len(data.prices) == 0:
        return None

    return data


async def store_history_data(data: Box, area_key: str, day: date, config: Config):
    """Store immutable historical price data to the filesystem."""
    store_dir = get_history_data_dir(config)
    store_dir.mkdir(parents=True, exist_ok=True)
    file_path = get_history_data_path(area_key, day, config)

    pickled_data = pickle.dumps(data)

    logger.info(f"Storing ENTSO-E {area_key} historical price data for {day} to {file_path}.")
    await utils.async_atomic_write_bytes(file_path, pickled_data)


def parse_to_response_data(price_data: Box) -> Box:
    """Parse app interal format to the response format."""
    # Don't create copy to need to explicitly make data included in response opt-in.
    response_data = Box()
    response_data.source = price_data.source
    response_data.area = price_data.area
    response_data.display_name = price_data.display_name
    response_data.entsoe_domain = price_data.entsoe_domain
    response_data.timezone = price_data.timezone
    response_data.currency = price_data.currency
    response_data.resolution = price_data.resolution
    response_data.sequence_position = price_data.sequence_position
    response_data.fallback_sequence_positions = list(price_data.get("fallback_sequence_positions", []))
    response_data.fallback_price_count = int(price_data.get("fallback_price_count", 0))
    response_data.prices = []
    for price_point in price_data.prices:
        response_point = Box()
        response_point.start_timestamp = price_point.start_timestamp.int_timestamp
        response_point.end_timestamp = price_point.end_timestamp.int_timestamp
        response_point.marketprice = float(price_point.marketprice.value)
        response_point.sequence_position = price_point.get("sequence_position", price_data.sequence_position)
        response_point.is_fallback = bool(price_point.get("is_fallback", False))
        response_data.prices.append(response_point)

    return response_data
