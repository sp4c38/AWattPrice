"""Poll and process generation mix data."""
import pickle
import xml.etree.ElementTree as ET

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
from awattprice.prices import area_file_key
from awattprice.prices import resolution_to_seconds


RENEWABLE_CATEGORIES = {"solar", "wind", "hydro", "biomass"}
RENEWABLE_PRODUCTION_TYPES = {"B01", "B09", "B10", "B11", "B12", "B13", "B15", "B16", "B18", "B19"}
PRODUCTION_TYPE_CATEGORIES = {
    "B01": "biomass",
    "B02": "fossil",
    "B03": "fossil",
    "B04": "fossil",
    "B05": "fossil",
    "B06": "fossil",
    "B07": "fossil",
    "B08": "fossil",
    "B09": "other",
    "B10": "hydro",
    "B11": "hydro",
    "B12": "hydro",
    "B13": "other",
    "B14": "nuclear",
    "B15": "other",
    "B16": "solar",
    "B17": "other",
    "B18": "wind",
    "B19": "wind",
    "B20": "other",
}
GENERATION_CATEGORIES = ["solar", "wind", "hydro", "biomass", "fossil", "nuclear", "other"]


async def get_stored_data(area_key: str, config: Config) -> Optional[Box]:
    """Get locally cached generation data."""
    file_dir = config.paths.generation_data_dir
    file_name = defaults.GENERATION_DATA_FILE_NAME.format(area_file_key(area_key))
    file_path = file_dir / file_name

    try:
        async with async_open(file_path, "rb") as file:
            unpickled_data = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No stored generation data found: {exc}.")
        return None

    if len(unpickled_data) == 0:
        return None

    data = pickle.loads(unpickled_data)
    if len(data.generation_points) == 0:
        return None

    return data


def production_category(psr_type: Optional[str]) -> str:
    """Map ENTSO-E production type codes to app categories."""
    if psr_type is None:
        return "other"

    return PRODUCTION_TYPE_CATEGORIES.get(psr_type, "other")


def parse_downloaded_data(area: MarketArea, xml_content: bytes) -> Box:
    """Parse ENTSO-E actual generation per production type into cached data."""
    root = ET.fromstring(xml_content)
    if root.tag.endswith("Acknowledgement_MarketDocument"):
        reason = root.findtext(".//{*}text") or "Unknown ENTSO-E error."
        raise ValueError(reason)

    selected_resolution = None
    new_data = Box()
    new_data.source = "ENTSOE"
    new_data.area = area.key
    new_data.display_name = area.display_name
    new_data.entsoe_domain = area.entsoe_domain
    new_data.timezone = area.timezone
    new_data.updated_at = arrow.now(area.timezone)
    # Keyed by (psr_type, psr_name, start_timestamp) so later TimeSeries entries
    # (amendments/corrections from ENTSO-E) overwrite earlier ones for the same
    # unit and time slot, while genuinely distinct units (different psr_name) are
    # kept separately and summed when grouped into categories.
    generation_points_by_key: dict = {}

    for time_series in root.findall(".//{*}TimeSeries"):
        psr_type = time_series.findtext("{*}MktPSRType/{*}psrType")
        psr_name = time_series.findtext("{*}MktPSRType/{*}powerSystemResources/{*}name")
        category = production_category(psr_type)

        for period in time_series.findall("{*}Period"):
            resolution = period.findtext("{*}resolution")
            if resolution is None:
                continue
            if selected_resolution is None:
                selected_resolution = resolution
            elif selected_resolution != resolution:
                raise ValueError(f"Mixed ENTSO-E generation resolutions for {area.key}: {selected_resolution} and {resolution}.")

            interval_seconds = resolution_to_seconds(resolution)
            period_start_text = period.findtext("{*}timeInterval/{*}start")
            if period_start_text is None:
                continue
            period_start = arrow.get(period_start_text).to(area.timezone)

            for point in period.findall("{*}Point"):
                position_text = point.findtext("{*}position")
                quantity_text = point.findtext("{*}quantity")
                if position_text is None or quantity_text is None:
                    continue

                generation_point = Box()
                position = int(position_text)
                generation_point.start_timestamp = period_start.shift(seconds=interval_seconds * (position - 1))
                generation_point.end_timestamp = generation_point.start_timestamp.shift(seconds=interval_seconds)
                generation_point.raw_production_type = psr_type
                generation_point.raw_production_name = psr_name
                generation_point.category = category
                generation_point.quantity_mw = Decimal(str(quantity_text))
                generation_point.is_renewable = psr_type in RENEWABLE_PRODUCTION_TYPES
                generation_points_by_key[(psr_type, psr_name, generation_point.start_timestamp.int_timestamp)] = generation_point

    new_data.resolution = selected_resolution
    new_data.generation_points = BoxList(sorted(generation_points_by_key.values(), key=lambda point: point.start_timestamp))
    if len(new_data.generation_points) == 0:
        raise ValueError(f"No usable ENTSO-E generation points found for {area.key}.")

    return new_data


async def store_data(data: Box, area_key: str, config: Config):
    """Store generation data to the filesystem."""
    file_name = defaults.GENERATION_DATA_FILE_NAME.format(area_file_key(area_key))
    file_path = config.paths.generation_data_dir / file_name

    logger.info(f"Storing ENTSO-E {area_key} generation data to {file_path}.")
    await utils.async_atomic_write_bytes(file_path, pickle.dumps(data))


def _intervals_by_end_timestamp(generation_data: Box) -> list[BoxList]:
    """Group all generation points into sorted per-interval buckets."""
    points_by_end = {}
    for point in generation_data.generation_points:
        points_by_end.setdefault(point.end_timestamp.int_timestamp, BoxList()).append(point)
    return [points_by_end[k] for k in sorted(points_by_end.keys())]


def latest_interval_points(generation_data: Box) -> BoxList:
    """Return generation points for the latest available interval."""
    return _intervals_by_end_timestamp(generation_data)[-1]


def category_values_for_points(points: BoxList) -> tuple[dict[str, Decimal], Decimal, Decimal]:
    """Group one interval's generation points into app categories."""
    categories = {category: Decimal("0") for category in GENERATION_CATEGORIES}
    for point in points:
        quantity_mw = max(point.quantity_mw, Decimal("0"))
        categories[point.category] = categories.get(point.category, Decimal("0")) + quantity_mw

    total_mw = sum(categories.values(), Decimal("0"))
    renewable_mw = sum(max(point.quantity_mw, Decimal("0")) for point in points if point.is_renewable)
    return categories, total_mw, renewable_mw


def category_response(category: str, quantity_mw: Decimal, total_mw: Decimal) -> Box:
    """Create the shared response model for one generation category."""
    response = Box()
    response.category = category
    response.generation_mw = float(quantity_mw)
    response.share = float((quantity_mw / total_mw) * 100) if total_mw > 0 else 0.0
    response.is_renewable = category in RENEWABLE_CATEGORIES
    return response


def interval_response(points: BoxList) -> Box:
    """Create a grouped app response for one generation interval."""
    categories, total_mw, renewable_mw = category_values_for_points(points)

    response = Box()
    response.start_timestamp = min(point.start_timestamp for point in points).int_timestamp
    response.end_timestamp = max(point.end_timestamp for point in points).int_timestamp
    response.total_generation_mw = float(total_mw)
    response.renewable_generation_mw = float(renewable_mw)
    response.renewable_share = float((renewable_mw / total_mw) * 100) if total_mw > 0 else 0.0
    response.categories = [
        category_response(category, categories[category], total_mw)
        for category in GENERATION_CATEGORIES
    ]
    return response


def parse_to_response_data(generation_data: Box) -> Box:
    """Parse cached generation data to the narrow app response."""
    points = latest_interval_points(generation_data)
    interval = interval_response(points)

    response = Box()
    response.source = generation_data.source
    response.area = generation_data.area
    response.display_name = generation_data.display_name
    response.entsoe_domain = generation_data.entsoe_domain
    response.timezone = generation_data.timezone
    response.resolution = generation_data.resolution
    response.updated_at = generation_data.updated_at.int_timestamp
    response.start_timestamp = interval.start_timestamp
    response.end_timestamp = interval.end_timestamp
    response.total_generation_mw = interval.total_generation_mw
    response.renewable_generation_mw = interval.renewable_generation_mw
    response.renewable_share = interval.renewable_share
    response.categories = interval.categories

    return response


def parse_to_history_response_data(generation_data: Box, hours: int = 24) -> Box:
    """Parse cached generation data to grouped app history for the requested hours."""
    all_intervals = _intervals_by_end_timestamp(generation_data)
    latest_end = max(point.end_timestamp for point in all_intervals[-1])
    cutoff = latest_end.shift(hours=-hours)
    interval_points = [
        points
        for points in all_intervals
        if max(point.end_timestamp for point in points) > cutoff
    ]
    interval_responses = BoxList([interval_response(points) for points in interval_points])

    categories = {category: Decimal("0") for category in GENERATION_CATEGORIES}
    total_mw = Decimal("0")
    renewable_mw = Decimal("0")
    for points in interval_points:
        interval_categories, interval_total_mw, interval_renewable_mw = category_values_for_points(points)
        total_mw += interval_total_mw
        renewable_mw += interval_renewable_mw
        for category, quantity_mw in interval_categories.items():
            categories[category] += quantity_mw

    response = Box()
    response.source = generation_data.source
    response.area = generation_data.area
    response.display_name = generation_data.display_name
    response.entsoe_domain = generation_data.entsoe_domain
    response.timezone = generation_data.timezone
    response.resolution = generation_data.resolution
    response.updated_at = generation_data.updated_at.int_timestamp
    response.start_timestamp = min(interval.start_timestamp for interval in interval_responses)
    response.end_timestamp = max(interval.end_timestamp for interval in interval_responses)
    response.total_generation_mw = float(total_mw)
    response.renewable_generation_mw = float(renewable_mw)
    response.renewable_share = float((renewable_mw / total_mw) * 100) if total_mw > 0 else 0.0
    response.categories = [
        category_response(category, categories[category], total_mw)
        for category in GENERATION_CATEGORIES
    ]
    response.intervals = interval_responses

    return response
