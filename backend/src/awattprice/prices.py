"""Poll and process price data."""
import pickle
import xml.etree.ElementTree as ET

from datetime import date
from decimal import Decimal
from typing import Optional

import arrow

from aiofile import async_open
from box import Box
from box import BoxList
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


def get_matching_time_series(root: ET.Element, area: MarketArea) -> list[ET.Element]:
    """Get the ENTSO-E time series matching the configured area."""
    matching_series = []
    for time_series in root.findall(".//{*}TimeSeries"):
        in_domain = time_series.findtext("{*}in_Domain.mRID")
        out_domain = time_series.findtext("{*}out_Domain.mRID")
        if in_domain != area.entsoe_domain or out_domain != area.entsoe_domain:
            continue
        matching_series.append(time_series)

    return matching_series


def select_time_series(area: MarketArea, time_series_list: list[ET.Element]) -> list[ET.Element]:
    """Select the ENTSO-E time series to use for the area."""
    if len(time_series_list) == 0:
        raise ValueError(f"No ENTSO-E price series found for {area.key}.")

    if len(time_series_list) == 1:
        return time_series_list

    if area.preferred_price_sequence is not None:
        preferred_time_series = [
            time_series
            for time_series in time_series_list
            if time_series.findtext("{*}classificationSequence_AttributeInstanceComponent.position")
            == str(area.preferred_price_sequence)
        ]
        if len(preferred_time_series) > 0:
            logger.debug(
                f"Selected ENTSO-E sequence {area.preferred_price_sequence} for {area.key}."
            )
            return preferred_time_series

    sequence_one_series = [
        time_series
        for time_series in time_series_list
        if time_series.findtext("{*}classificationSequence_AttributeInstanceComponent.position") == "1"
    ]
    if len(sequence_one_series) > 0:
        logger.warning(f"Falling back to ENTSO-E sequence 1 for {area.key}.")
        return sequence_one_series

    logger.warning(f"Multiple ENTSO-E series found for {area.key}. Falling back to the first one.")
    return [time_series_list[0]]


def parse_downloaded_data(area: MarketArea, xml_content: bytes) -> Box:
    """Parse the downloaded ENTSO-E price data into the app internal format."""
    root = ET.fromstring(xml_content)
    if root.tag.endswith("Acknowledgement_MarketDocument"):
        reason = root.findtext(".//{*}text") or "Unknown ENTSO-E error."
        raise ValueError(reason)

    matching_time_series = get_matching_time_series(root, area)
    selected_time_series_list = select_time_series(area, matching_time_series)
    first_selected_time_series = selected_time_series_list[0]

    selected_resolution = None
    new_data = Box()
    new_data.source = "ENTSOE"
    new_data.area = area.key
    new_data.display_name = area.display_name
    new_data.entsoe_domain = area.entsoe_domain
    new_data.timezone = area.timezone
    new_data.currency = first_selected_time_series.findtext("{*}currency_Unit.name") or area.currency
    new_data.sequence_position = first_selected_time_series.findtext(
        "{*}classificationSequence_AttributeInstanceComponent.position"
    )
    new_data.prices = BoxList()
    for selected_time_series in selected_time_series_list:
        for period in selected_time_series.findall("{*}Period"):
            resolution = period.findtext("{*}resolution")
            if resolution is None:
                continue
            if selected_resolution is None:
                selected_resolution = resolution
            elif selected_resolution != resolution:
                raise ValueError(f"Mixed ENTSO-E resolutions for {area.key}: {selected_resolution} and {resolution}.")

            interval_seconds = resolution_to_seconds(resolution)
            period_start = arrow.get(period.findtext("{*}timeInterval/{*}start")).to(area.timezone)

            for point in period.findall("{*}Point"):
                position_text = point.findtext("{*}position")
                price_text = point.findtext("{*}price.amount")
                if position_text is None or price_text is None:
                    continue

                new_point = Box()
                position = int(position_text)
                new_point.start_timestamp = period_start.shift(seconds=interval_seconds * (position - 1))
                new_point.end_timestamp = new_point.start_timestamp.shift(seconds=interval_seconds)
                new_point.marketprice = MarketPrice(Decimal(str(price_text)), area)
                new_data.prices.append(new_point)

    new_data.resolution = selected_resolution
    new_data.prices = BoxList(sorted(new_data.prices, key=lambda point: point.start_timestamp))
    if len(new_data.prices) == 0:
        raise ValueError(f"No usable ENTSO-E price points found for {area.key}.")

    return new_data


async def store_data(data: Box, area_key: str, config: Config):
    """Store new price data to the filesystem."""
    store_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_FILE_NAME.format(area_file_key(area_key))
    file_path = store_dir / file_name

    pickled_data = pickle.dumps(data)

    logger.info(f"Storing ENTSO-E {area_key} price data to {file_path}.")
    async with async_open(file_path, "wb") as file:
        await file.write(pickled_data)


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
    async with async_open(file_path, "wb") as file:
        await file.write(pickled_data)


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
    response_data.prices = []
    for price_point in price_data.prices:
        response_point = Box()
        response_point.start_timestamp = price_point.start_timestamp.int_timestamp
        response_point.end_timestamp = price_point.end_timestamp.int_timestamp
        response_point.marketprice = float(price_point.marketprice.value)
        response_data.prices.append(response_point)

    return response_data
