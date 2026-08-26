"""Poll, store, and process price data."""
import asyncio
import json

from datetime import date
from decimal import Decimal
from typing import Optional

import arrow

from arrow import Arrow
from box import Box
from liteconfig import Config

from awattprice import defaults
from awattprice import price_database
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


def resolution_to_seconds(resolution: str) -> int:
    """Convert a simple ISO8601 ENTSO-E duration to seconds."""
    resolution_mapping = {
        "PT15M": 15 * 60,
        "PT30M": 30 * 60,
        "PT60M": 60 * 60,
    }
    return resolution_mapping[resolution]


def _database_rows_to_price_data(
    rows: list[dict],
    area: MarketArea,
    metadata: Optional[dict] = None,
) -> Optional[Box]:
    """Reconstruct the established in-memory price format from SQLite rows."""
    if not rows:
        return None
    data = Box()
    data.source = metadata["source"] if metadata else "ENTSOE"
    data.area = metadata["area_key"] if metadata else area.key
    data.display_name = metadata["display_name"] if metadata else area.display_name
    data.entsoe_domain = metadata["entsoe_domain"] if metadata else area.entsoe_domain
    data.timezone = metadata["timezone"] if metadata else area.timezone
    data.currency = metadata["currency"] if metadata else area.currency
    resolutions = {row["resolution"] for row in rows if row["resolution"] is not None}
    data.resolution = metadata["resolution"] if metadata else (
        next(iter(resolutions)) if len(resolutions) == 1 else None
    )
    primary_sequences = [
        row["sequence_position"]
        for row in rows
        if not row["is_fallback"] and row["sequence_position"] is not None
    ]
    data.sequence_position = metadata["sequence_position"] if metadata else (
        primary_sequences[0] if primary_sequences else None
    )
    if metadata:
        data.fallback_sequence_positions = json.loads(metadata["fallback_sequence_positions"])
        data.fallback_price_count = metadata["fallback_price_count"]
        data.carried_forward_price_count = metadata["carried_forward_price_count"]
    else:
        data.fallback_sequence_positions = sorted(
            {
                row["sequence_position"]
                for row in rows
                if row["is_fallback"] and row["sequence_position"] is not None
            }
        )
        data.fallback_price_count = sum(int(row["is_fallback"]) for row in rows)
        data.carried_forward_price_count = sum(int(row["is_carried_forward"]) for row in rows)
    data.prices = []
    for row in rows:
        point = Box()
        point.start_timestamp = arrow.get(row["start_timestamp"]).to(area.timezone)
        point.end_timestamp = arrow.get(row["end_timestamp"]).to(area.timezone)
        point.marketprice = MarketPrice(Decimal(row["marketprice"]), area)
        point.resolution = row["resolution"]
        point.sequence_position = row["sequence_position"]
        point.is_fallback = bool(row["is_fallback"])
        point.is_carried_forward = bool(row["is_carried_forward"])
        data.prices.append(point)
    return data


def _database_payload_to_price_data(payload: dict, area: MarketArea) -> Optional[Box]:
    """Reconstruct a named SQLite dataset."""
    return _database_rows_to_price_data(payload["points"], area, payload["dataset"])


async def get_stored_data(area_key: str, config: Config) -> Optional[Box]:
    """Get current price data from SQLite."""
    normalized_area_key = defaults.normalize_market_area_key(area_key)
    area = defaults.get_market_area(normalized_area_key)
    payload = await asyncio.to_thread(
        price_database.load_dataset,
        config,
        normalized_area_key,
        "current",
    )
    if payload is None:
        return None
    return _database_payload_to_price_data(payload, area)


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


def _price_point_signature(price_point: Box) -> tuple[int, int, str, Optional[str], bool, bool]:
    return (
        price_point.start_timestamp.int_timestamp,
        price_point.end_timestamp.int_timestamp,
        str(price_point.marketprice.value),
        price_point.get("sequence_position"),
        bool(price_point.get("is_fallback", False)),
        bool(price_point.get("is_carried_forward", False)),
    )


def price_data_signature(price_data: Box) -> tuple[tuple[int, int, str, Optional[str], bool, bool], ...]:
    """Build a stable signature for comparing cached price payloads."""
    return tuple(sorted(_price_point_signature(price_point) for price_point in price_data.prices))


def unique_price_point_count(price_data: Box) -> int:
    """Count unique start timestamps in a price payload."""
    return len({price_point.start_timestamp.int_timestamp for price_point in price_data.prices})


def fallback_price_count(price_data: Box) -> int:
    """Count prices that were filled from a non-primary sequence."""
    return sum(1 for price_point in price_data.prices if price_point.get("is_fallback", False))


def carried_forward_price_count(price_data: Box) -> int:
    """Count prices carried forward from an ENTSO-E A03 step curve."""
    return sum(1 for price_point in price_data.prices if price_point.get("is_carried_forward", False))


def has_fallback_price_points(price_data: Optional[Box], period_start: Arrow, period_end: Arrow) -> bool:
    """Return true when any price point in the given period was filled from a fallback sequence."""
    if price_data is None or not price_data.prices:
        return False
    return any(
        price_point.get("is_fallback", False)
        and price_point.start_timestamp.int_timestamp >= period_start.int_timestamp
        and price_point.end_timestamp.int_timestamp <= period_end.int_timestamp
        for price_point in price_data.prices
    )


def has_complete_price_points(price_data: Optional[Box], period_start: Arrow, period_end: Arrow) -> bool:
    """Return true when price intervals continuously cover a period."""
    if price_data is None or not price_data.prices:
        return False
    selected = sorted(
        (
            price_point.start_timestamp.int_timestamp,
            price_point.end_timestamp.int_timestamp,
        )
        for price_point in price_data.prices
        if (
            price_point.start_timestamp.int_timestamp >= period_start.int_timestamp
            and price_point.end_timestamp.int_timestamp <= period_end.int_timestamp
        )
    )
    cursor = period_start.int_timestamp
    for start_timestamp, end_timestamp in selected:
        if start_timestamp != cursor or end_timestamp <= start_timestamp:
            return False
        cursor = end_timestamp
    return cursor == period_end.int_timestamp


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
    if not has_complete_price_points(price_data, tomorrow_start, tomorrow_end):
        return False
    return not has_fallback_price_points(price_data, tomorrow_start, tomorrow_end)


async def store_data(data: Box, area_key: str, config: Config):
    """Store current price data in SQLite."""
    normalized_area_key = defaults.normalize_market_area_key(area_key)
    await asyncio.to_thread(
        price_database.store_dataset,
        config,
        normalized_area_key,
        "current",
        data,
    )


async def get_stored_history_data(area_key: str, day: date, config: Config) -> Optional[Box]:
    """Get a historical day from SQLite."""
    normalized_area_key = defaults.normalize_market_area_key(area_key)
    area = defaults.get_market_area(normalized_area_key)
    dataset_key = f"history:{day.isoformat()}"
    payload = await asyncio.to_thread(
        price_database.load_dataset,
        config,
        normalized_area_key,
        dataset_key,
    )
    if payload is None:
        period_start = arrow.get(day.isoformat(), "YYYY-MM-DD", tzinfo=area.timezone)
        period_end = period_start.shift(days=+1)
        rows = await asyncio.to_thread(
            price_database.load_points,
            config,
            normalized_area_key,
            period_start.int_timestamp,
            period_end.int_timestamp,
        )
        stored_data = _database_rows_to_price_data(rows, area)
        if stored_data is None or not has_complete_price_points(stored_data, period_start, period_end):
            return None
        return stored_data
    return _database_payload_to_price_data(payload, area)


async def store_history_data(data: Box, area_key: str, day: date, config: Config):
    """Store a historical day in SQLite."""
    normalized_area_key = defaults.normalize_market_area_key(area_key)
    await asyncio.to_thread(
        price_database.store_dataset,
        config,
        normalized_area_key,
        f"history:{day.isoformat()}",
        data,
    )


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
    response_data.carried_forward_price_count = int(price_data.get("carried_forward_price_count", 0))
    response_data.prices = []
    for price_point in price_data.prices:
        response_point = Box()
        response_point.start_timestamp = price_point.start_timestamp.int_timestamp
        response_point.end_timestamp = price_point.end_timestamp.int_timestamp
        response_point.marketprice = float(price_point.marketprice.value)
        response_point.sequence_position = price_point.get("sequence_position", price_data.sequence_position)
        response_point.is_fallback = bool(price_point.get("is_fallback", False))
        response_point.is_carried_forward = bool(price_point.get("is_carried_forward", False))
        response_data.prices.append(response_point)

    return response_data
