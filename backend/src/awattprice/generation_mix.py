"""Poll and process generation mix data."""
import bisect
import json
import xml.etree.ElementTree as ET

from collections import defaultdict
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

# An interval counts as a partial publication when the production types that are
# missing there (estimated from each type's last known value) make up more than
# this fraction of the interval's estimated total generation.  This filters out
# negligible trailing/gap drop-offs (e.g. a small oil plant) while still flagging
# materially incomplete intervals (e.g. a multi-GW wind series with a gap).
PARTIAL_PUBLICATION_MAGNITUDE_THRESHOLD = Decimal("0.02")


def get_history_response_data_path(area_key: str, hours: int, config: Config):
    """Get the precomputed generation history response path."""
    file_name = defaults.GENERATION_HISTORY_RESPONSE_FILE_NAME.format(area_file_key(area_key), hours)
    return config.paths.generation_data_dir / file_name


def get_published_history_response_data_path(area_key: str, hours: int, config: Config):
    """Get the precomputed published generation history response path."""
    file_name = defaults.GENERATION_PUBLISHED_HISTORY_RESPONSE_FILE_NAME.format(area_file_key(area_key), hours)
    return config.paths.generation_data_dir / file_name


def get_metadata_path(area_key: str, config: Config):
    """Get the generation metadata path."""
    file_name = defaults.GENERATION_METADATA_FILE_NAME.format(area_file_key(area_key))
    return config.paths.generation_data_dir / file_name


async def get_stored_history_response_json(area_key: str, hours: int, config: Config) -> Optional[bytes]:
    """Get precomputed generation history response JSON."""
    file_path = get_history_response_data_path(area_key, hours, config)

    try:
        async with async_open(file_path, "rb") as file:
            response_json = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No stored generation history response found: {exc}.")
        return None

    if len(response_json) == 0:
        return None

    return response_json


async def get_stored_published_history_response_json(area_key: str, hours: int, config: Config) -> Optional[bytes]:
    """Get precomputed published generation history response JSON."""
    file_path = get_published_history_response_data_path(area_key, hours, config)

    try:
        async with async_open(file_path, "rb") as file:
            response_json = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No stored published generation history response found: {exc}.")
        return None

    if len(response_json) == 0:
        return None

    return response_json


async def get_stored_metadata(area_key: str, config: Config) -> Optional[Box]:
    """Get stored generation metadata."""
    file_path = get_metadata_path(area_key, config)

    try:
        async with async_open(file_path, "r") as file:
            metadata_json = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No stored generation metadata found: {exc}.")
        return None

    if len(metadata_json) == 0:
        return None

    return Box(json.loads(metadata_json))


async def store_metadata(metadata: Box, area_key: str, config: Config):
    """Store generation metadata."""
    file_path = get_metadata_path(area_key, config)
    logger.info(f"Storing ENTSO-E {area_key} generation metadata to {file_path}.")
    await utils.async_atomic_write_text(file_path, json.dumps(metadata, separators=(",", ":"), ensure_ascii=False))


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

            # ENTSO-E publishes these curves as curveType A03 (variable sized
            # block): a point's value holds until the next published position, so
            # omitted positions *inside* a Period are unchanged values, not
            # missing data (e.g. solar staying 0 all night).  We forward-fill
            # within the Period's published span.  Gaps *between* Periods are left
            # empty on purpose — those are genuinely unpublished intervals.
            quantities_by_position = {}
            for point in period.findall("{*}Point"):
                position_text = point.findtext("{*}position")
                quantity_text = point.findtext("{*}quantity")
                if position_text is None or quantity_text is None:
                    continue
                quantities_by_position[int(position_text)] = Decimal(str(quantity_text))

            if not quantities_by_position:
                continue

            held_quantity = None
            for position in range(min(quantities_by_position), max(quantities_by_position) + 1):
                if position in quantities_by_position:
                    held_quantity = quantities_by_position[position]

                generation_point = Box()
                generation_point.start_timestamp = period_start.shift(seconds=interval_seconds * (position - 1))
                generation_point.end_timestamp = generation_point.start_timestamp.shift(seconds=interval_seconds)
                generation_point.raw_production_type = psr_type
                generation_point.raw_production_name = psr_name
                generation_point.category = category
                generation_point.quantity_mw = held_quantity
                generation_point.is_renewable = psr_type in RENEWABLE_PRODUCTION_TYPES
                generation_points_by_key[(psr_type, psr_name, generation_point.start_timestamp.int_timestamp)] = generation_point

    new_data.resolution = selected_resolution
    new_data.generation_points = BoxList(sorted(generation_points_by_key.values(), key=lambda point: point.start_timestamp))
    if len(new_data.generation_points) == 0:
        raise ValueError(f"No usable ENTSO-E generation points found for {area.key}.")

    return new_data


def response_data_to_json_bytes(response_data: Box) -> bytes:
    """Serialize response data once so the API can serve it without rebuilding."""
    return json.dumps(response_data, separators=(",", ":"), ensure_ascii=False).encode()


async def store_history_response_json(response_json: bytes, area_key: str, hours: int, config: Config):
    """Store precomputed generation history response JSON."""
    file_path = get_history_response_data_path(area_key, hours, config)
    logger.info(f"Storing ENTSO-E {area_key} generation history response data to {file_path}.")
    await utils.async_atomic_write_bytes(file_path, response_json)


async def store_published_history_response_json(response_json: bytes, area_key: str, hours: int, config: Config):
    """Store precomputed published generation history response JSON."""
    file_path = get_published_history_response_data_path(area_key, hours, config)
    logger.info(f"Storing ENTSO-E {area_key} published generation history response data to {file_path}.")
    await utils.async_atomic_write_bytes(file_path, response_json)


def metadata_from_response_data(data: Box, response_data: Box, hours: int) -> Box:
    """Build compact generation metadata from response data."""
    metadata = Box()
    metadata.source = data.source
    metadata.area = data.area
    metadata.display_name = data.display_name
    metadata.entsoe_domain = data.entsoe_domain
    metadata.timezone = data.timezone
    metadata.resolution = data.resolution
    metadata.updated_at = data.updated_at.int_timestamp
    metadata.history_hours = hours
    metadata.coverage_start = response_data.start_timestamp
    metadata.coverage_end = response_data.end_timestamp
    metadata.latest_generation_end = max(point.end_timestamp for point in data.generation_points).int_timestamp
    metadata.interval_count = len(response_data.intervals)
    return metadata


async def store_response_data(
    data: Box,
    response_data: Box,
    area_key: str,
    hours: int,
    config: Config,
    published_response_data: Optional[Box] = None,
) -> Box:
    """Store generation history response JSON and metadata."""
    metadata = metadata_from_response_data(data, response_data, hours)
    await store_history_response_json(response_data_to_json_bytes(response_data), area_key, hours, config)
    if published_response_data is not None:
        await store_published_history_response_json(
            response_data_to_json_bytes(published_response_data),
            area_key,
            hours,
            config,
        )
    await store_metadata(metadata, area_key, config)
    return metadata


def _intervals_by_end_timestamp(generation_data: Box) -> list[BoxList]:
    """Group all generation points into sorted per-interval buckets."""
    points_by_end = {}
    for point in generation_data.generation_points:
        points_by_end.setdefault(point.end_timestamp.int_timestamp, BoxList()).append(point)
    return [points_by_end[k] for k in sorted(points_by_end.keys())]


def _interval_end_timestamp(points: BoxList) -> int:
    """Return the end timestamp shared by one interval's points."""
    return max(point.end_timestamp for point in points).int_timestamp


def _series_by_production_type(generation_data: Box) -> dict[Optional[str], list[tuple[int, Decimal]]]:
    """Per production type, the sorted (interval-end, total MW) it has published.

    Quantities are summed across units of the same type per interval so the
    series mirrors the per-type totals ENTSO-E reports.
    """
    totals: dict[Optional[str], dict[int, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    for point in generation_data.generation_points:
        end_timestamp = point.end_timestamp.int_timestamp
        totals[point.raw_production_type][end_timestamp] += max(point.quantity_mw, Decimal("0"))
    return {ptype: sorted(by_end.items()) for ptype, by_end in totals.items()}


def _last_known_quantity(series: list[tuple[int, Decimal]], end_timestamp: int) -> Optional[Decimal]:
    """Return a type's most recent published MW at or before an interval end.

    Used to estimate how much generation a not-yet-published type would have
    contributed.  Returns ``None`` when the type has no data yet at that point
    (so it has not started reporting, rather than dropping out of a gap).
    """
    ends = [end for end, _ in series]
    index = bisect.bisect_right(ends, end_timestamp) - 1
    if index < 0:
        return None
    return series[index][1]


def _partial_interval_flags(
    generation_data: Box,
    threshold: Decimal = PARTIAL_PUBLICATION_MAGNITUDE_THRESHOLD,
) -> dict[int, bool]:
    """Map each interval end timestamp to whether it is a partial publication.

    An interval is partial when production types that are expected for the window
    (they report data somewhere) are missing here and the estimated missing
    generation exceeds ``threshold`` of the interval's estimated total.
    """
    series_by_type = _series_by_production_type(generation_data)
    expected_types = set(series_by_type)

    flags: dict[int, bool] = {}
    for points in _intervals_by_end_timestamp(generation_data):
        end_timestamp = _interval_end_timestamp(points)
        present_types = {point.raw_production_type for point in points}
        present_mw = sum((max(point.quantity_mw, Decimal("0")) for point in points), Decimal("0"))

        missing_mw = Decimal("0")
        for ptype in expected_types - present_types:
            estimate = _last_known_quantity(series_by_type[ptype], end_timestamp)
            if estimate is not None:
                missing_mw += estimate

        total_mw = present_mw + missing_mw
        flags[end_timestamp] = total_mw > 0 and missing_mw > threshold * total_mw
    return flags


def _publication_metadata(generation_data: Box, flags: dict[int, bool]) -> Box:
    """Build metadata describing ENTSO-E partial publication state."""
    end_timestamps = [_interval_end_timestamp(points) for points in _intervals_by_end_timestamp(generation_data)]
    complete_ends = [end for end in end_timestamps if not flags[end]]

    latest_published_end = max(end_timestamps)
    latest_complete_end = max(complete_ends) if complete_ends else latest_published_end

    metadata = Box()
    metadata.is_partial_publication = any(flags.values())
    metadata.latest_complete_end_timestamp = latest_complete_end
    metadata.latest_published_end_timestamp = latest_published_end
    return metadata


def _trailing_complete_intervals(generation_data: Box, flags: dict[int, bool]) -> list[BoxList]:
    """Return all intervals with only trailing partial ones trimmed.

    Mid-window partial intervals are kept as-is; this just drops the trailing
    not-yet-fully-published tail so the legacy ``intervals.last`` stays usable.
    """
    intervals = _intervals_by_end_timestamp(generation_data)
    end_idx = len(intervals)
    while end_idx > 0 and flags[_interval_end_timestamp(intervals[end_idx - 1])]:
        end_idx -= 1
    return intervals[:end_idx]


def latest_complete_interval_points(generation_data: Box, flags: dict[int, bool]) -> BoxList:
    """Return the most recent interval that is not a partial publication."""
    intervals = _intervals_by_end_timestamp(generation_data)
    for points in reversed(intervals):
        if not flags[_interval_end_timestamp(points)]:
            return points
    return intervals[-1]


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


def interval_response(points: BoxList, is_partial_publication: bool = False) -> Box:
    """Create a grouped app response for one generation interval."""
    categories, total_mw, renewable_mw = category_values_for_points(points)

    response = Box()
    response.start_timestamp = min(point.start_timestamp for point in points).int_timestamp
    response.end_timestamp = max(point.end_timestamp for point in points).int_timestamp
    response.total_generation_mw = float(total_mw)
    response.renewable_generation_mw = float(renewable_mw)
    response.renewable_share = float((renewable_mw / total_mw) * 100) if total_mw > 0 else 0.0
    response.is_partial_publication = is_partial_publication
    response.categories = [
        category_response(category, categories[category], total_mw)
        for category in GENERATION_CATEGORIES
    ]
    return response


def parse_to_response_data(generation_data: Box) -> Box:
    """Parse cached generation data to the narrow app response."""
    flags = _partial_interval_flags(generation_data)
    points = latest_complete_interval_points(generation_data, flags)
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
    response.update(_publication_metadata(generation_data, flags))

    return response


def parse_to_history_response_data(generation_data: Box, hours: int = 24) -> Box:
    """Parse cached generation data to grouped app history for the requested hours."""
    flags = _partial_interval_flags(generation_data)
    all_intervals = _trailing_complete_intervals(generation_data, flags)
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
    response.update(_publication_metadata(generation_data, flags))

    return response


def parse_to_published_history_response_data(generation_data: Box, hours: int = 24) -> Box:
    """Parse cached generation data to history including partial published intervals."""
    flags = _partial_interval_flags(generation_data)
    all_intervals = _intervals_by_end_timestamp(generation_data)
    latest_end = max(point.end_timestamp for point in all_intervals[-1])
    cutoff = latest_end.shift(hours=-hours)
    interval_points = [
        points
        for points in all_intervals
        if max(point.end_timestamp for point in points) > cutoff
    ]
    complete_interval_points = [
        points
        for points in interval_points
        if not flags[_interval_end_timestamp(points)]
    ]
    summary_points = complete_interval_points if complete_interval_points else interval_points
    interval_responses = BoxList([
        interval_response(
            points,
            is_partial_publication=flags[_interval_end_timestamp(points)],
        )
        for points in interval_points
    ])

    categories = {category: Decimal("0") for category in GENERATION_CATEGORIES}
    total_mw = Decimal("0")
    renewable_mw = Decimal("0")
    for points in summary_points:
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
    complete_ends = [interval.end_timestamp for interval in interval_responses if not interval.is_partial_publication]
    response.is_partial_publication = any(interval.is_partial_publication for interval in interval_responses)
    response.latest_published_end_timestamp = max(interval.end_timestamp for interval in interval_responses)
    response.latest_complete_end_timestamp = max(complete_ends) if complete_ends else response.latest_published_end_timestamp

    return response
