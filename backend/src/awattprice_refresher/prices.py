"""Refresh ENTSO-E price caches."""
import filelock
import httpx
import xml.etree.ElementTree as ET

from bisect import bisect_left
from datetime import date
from decimal import Decimal
from collections.abc import Iterator
from typing import Optional

import arrow

from arrow import Arrow
from box import Box
from box import BoxList
from liteconfig import Config
from loguru import logger
from tenacity import (
    AsyncRetrying,
    retry_if_exception_type,
    stop_after_attempt,
    stop_after_delay,
    wait_exponential,
)

from awattprice import defaults
from awattprice import prices
from awattprice import utils
from awattprice.market_areas import MarketArea
from awattprice.utils import ExtendedFileLock
from awattprice.utils import acquire_file_lock_immediate
from awattprice.utils import log_attempts


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


def time_series_sequence_position(time_series: ET.Element) -> Optional[str]:
    """Get the ENTSO-E sequence position for one time series."""
    return time_series.findtext("{*}classificationSequence_AttributeInstanceComponent.position")


def time_series_curve_type(time_series: ET.Element) -> Optional[str]:
    """Get the ENTSO-E curve type for one time series."""
    return time_series.findtext("{*}curveType")


def select_time_series(area: MarketArea, time_series_list: list[ET.Element]) -> list[ET.Element]:
    """Select ENTSO-E time series in preferred order for import."""
    if len(time_series_list) == 0:
        raise ValueError(f"No ENTSO-E price series found for {area.key}.")

    if len(time_series_list) == 1:
        return time_series_list

    sequence_values = [time_series_sequence_position(time_series) for time_series in time_series_list]
    if all(sequence is None for sequence in sequence_values):
        logger.debug(f"Using all unclassified ENTSO-E price series for {area.key}.")
        return time_series_list

    preferred_sequence = str(area.preferred_price_sequence) if area.preferred_price_sequence is not None else None

    def sequence_priority(time_series: ET.Element) -> tuple[int, int]:
        sequence_position = time_series_sequence_position(time_series)
        if sequence_position == preferred_sequence:
            return 0, 0
        if sequence_position == "1":
            return 1, 1
        if sequence_position == "2":
            return 2, 2
        if sequence_position is None:
            return 99, 99
        try:
            return 10 + int(sequence_position), int(sequence_position)
        except ValueError:
            return 90, 90

    selected_time_series = sorted(time_series_list, key=sequence_priority)
    selected_sequence_values = [
        sequence
        for sequence in [time_series_sequence_position(time_series) for time_series in selected_time_series]
        if sequence is not None
    ]
    if preferred_sequence in selected_sequence_values:
        logger.debug(
            f"Selected ENTSO-E sequence {preferred_sequence} for {area.key} "
            f"with fallback sequences {selected_sequence_values[1:]}."
        )
    else:
        logger.warning(
            f"Preferred ENTSO-E sequence {preferred_sequence} for {area.key} was not found. "
            f"Using sequences {selected_sequence_values}."
        )

    return selected_time_series


def preferred_sequence_position(area: MarketArea, selected_time_series_list: list[ET.Element]) -> Optional[str]:
    """Get the sequence that should be treated as the primary auction."""
    sequence_positions = [time_series_sequence_position(time_series) for time_series in selected_time_series_list]
    if area.preferred_price_sequence is not None and any(sequence is not None for sequence in sequence_positions):
        return str(area.preferred_price_sequence)
    return sequence_positions[0]


def iter_time_series_points(
    time_series_list: list[ET.Element],
    area: MarketArea,
) -> Iterator[tuple[Optional[str], str, Arrow, Arrow, str, bool]]:
    """Yield parsed ENTSO-E price point fields from selected time series."""
    for time_series in time_series_list:
        sequence_position = time_series_sequence_position(time_series)
        curve_type = time_series_curve_type(time_series)
        for period in time_series.findall("{*}Period"):
            resolution = period.findtext("{*}resolution")
            period_start_text = period.findtext("{*}timeInterval/{*}start")
            period_end_text = period.findtext("{*}timeInterval/{*}end")
            if resolution is None or period_start_text is None:
                continue

            interval_seconds = prices.resolution_to_seconds(resolution)
            period_start = arrow.get(period_start_text).to(area.timezone)
            explicit_points = {}
            for point in period.findall("{*}Point"):
                position_text = point.findtext("{*}position")
                price_text = point.findtext("{*}price.amount")
                if position_text is None or price_text is None:
                    continue

                explicit_points[int(position_text)] = price_text

            if curve_type != "A03" or period_end_text is None:
                for position, price_text in sorted(explicit_points.items()):
                    start_timestamp = arrow.get(
                        period_start.int_timestamp + interval_seconds * (position - 1)
                    ).to(area.timezone)
                    yield (
                        sequence_position,
                        resolution,
                        start_timestamp,
                        arrow.get(start_timestamp.int_timestamp + interval_seconds).to(area.timezone),
                        price_text,
                        False,
                    )
                continue

            period_end = arrow.get(period_end_text).to(area.timezone)
            expected_point_count = int((period_end.int_timestamp - period_start.int_timestamp) / interval_seconds)
            current_price_text = None
            for position in range(1, expected_point_count + 1):
                carried_forward = False
                if position in explicit_points:
                    current_price_text = explicit_points[position]
                elif current_price_text is not None:
                    carried_forward = True
                else:
                    continue

                start_timestamp = arrow.get(
                    period_start.int_timestamp + interval_seconds * (position - 1)
                ).to(area.timezone)
                yield (
                    sequence_position,
                    resolution,
                    start_timestamp,
                    arrow.get(start_timestamp.int_timestamp + interval_seconds).to(area.timezone),
                    current_price_text,
                    carried_forward,
                )


def local_days_with_sequence_price(
    time_series_list: list[ET.Element],
    area: MarketArea,
    sequence_position: Optional[str],
) -> set[date]:
    """Return local days with at least one price in the given sequence."""
    return {
        start_timestamp.date()
        for point_sequence, _, start_timestamp, _, _, _ in iter_time_series_points(time_series_list, area)
        if point_sequence == sequence_position
    }


def has_blocked_full_day_fallback(data: Optional[Box], area: MarketArea, now: Optional[Arrow] = None) -> bool:
    """Return true when cached tomorrow prices are only from fallback before the cutoff."""
    if data is None or not data.prices:
        return False

    now_local = (now or arrow.now(area.timezone)).to(area.timezone)
    if now_local.hour >= defaults.ENTSOE_FULL_FALLBACK_UPDATE_HOUR:
        return False

    tomorrow = now_local.floor("day").shift(days=+1).date()
    tomorrow_prices = [
        price_point
        for price_point in data.prices
        if price_point.start_timestamp.to(area.timezone).date() == tomorrow
    ]
    if not tomorrow_prices:
        return False

    preferred_sequence = str(area.preferred_price_sequence) if area.preferred_price_sequence is not None else None
    has_primary_price = any(
        not price_point.get("is_fallback", False)
        and (
            preferred_sequence is None
            or price_point.get("sequence_position", data.get("sequence_position")) == preferred_sequence
        )
        for price_point in tomorrow_prices
    )
    return not has_primary_price and any(price_point.get("is_fallback", False) for price_point in tomorrow_prices)


def parse_downloaded_data(area: MarketArea, xml_content: bytes, now: Optional[Arrow] = None) -> Box:
    """Parse downloaded ENTSO-E price data into the cache format."""
    root = ET.fromstring(xml_content)
    if root.tag.endswith("Acknowledgement_MarketDocument"):
        reason = root.findtext(".//{*}text") or "Unknown ENTSO-E error."
        raise ValueError(reason)

    matching_time_series = get_matching_time_series(root, area)
    selected_time_series_list = select_time_series(area, matching_time_series)
    first_selected_time_series = selected_time_series_list[0]
    primary_sequence_position = preferred_sequence_position(area, selected_time_series_list)
    primary_local_days = local_days_with_sequence_price(selected_time_series_list, area, primary_sequence_position)
    now_local = (now or arrow.now(area.timezone)).to(area.timezone)
    tomorrow = now_local.floor("day").shift(days=+1).date()
    block_fallback_only_tomorrow = now_local.hour < defaults.ENTSOE_FULL_FALLBACK_UPDATE_HOUR

    selected_resolutions = set()
    new_data = Box()
    new_data.source = "ENTSOE"
    new_data.area = area.key
    new_data.display_name = area.display_name
    new_data.entsoe_domain = area.entsoe_domain
    new_data.timezone = area.timezone
    new_data.currency = first_selected_time_series.findtext("{*}currency_Unit.name") or area.currency
    new_data.sequence_position = primary_sequence_position
    new_data.fallback_sequence_positions = []
    new_data.fallback_price_count = 0
    new_data.carried_forward_price_count = 0
    prices_by_start_timestamp = {}
    selected_start_timestamps = []
    for sequence_position, resolution, start_timestamp, end_timestamp, price_text, carried_forward in iter_time_series_points(
        selected_time_series_list,
        area,
    ):
        selected_resolutions.add(resolution)

        new_point = Box()
        new_point.start_timestamp = start_timestamp
        new_point.end_timestamp = end_timestamp
        new_point.marketprice = prices.MarketPrice(Decimal(str(price_text)), area)
        new_point.resolution = resolution
        new_point.sequence_position = sequence_position
        new_point.is_fallback = sequence_position != new_data.sequence_position
        new_point.is_carried_forward = carried_forward

        local_day = new_point.start_timestamp.date()
        if (
            new_point.is_fallback
            and local_day not in primary_local_days
            and local_day == tomorrow
            and block_fallback_only_tomorrow
        ):
            continue

        start_int_timestamp = new_point.start_timestamp.int_timestamp
        end_int_timestamp = new_point.end_timestamp.int_timestamp
        insertion_index = bisect_left(selected_start_timestamps, start_int_timestamp)
        overlaps_previous = insertion_index > 0 and (
            prices_by_start_timestamp[selected_start_timestamps[insertion_index - 1]]
            .end_timestamp.int_timestamp
            > start_int_timestamp
        )
        overlaps_next = insertion_index < len(selected_start_timestamps) and (
            selected_start_timestamps[insertion_index] < end_int_timestamp
        )
        if overlaps_previous or overlaps_next:
            continue
        if new_point.is_fallback:
            new_data.fallback_price_count += 1
            if sequence_position not in new_data.fallback_sequence_positions:
                new_data.fallback_sequence_positions.append(sequence_position)
        if new_point.is_carried_forward:
            new_data.carried_forward_price_count += 1
        prices_by_start_timestamp[start_int_timestamp] = new_point
        selected_start_timestamps.insert(insertion_index, start_int_timestamp)

    new_data.resolution = next(iter(selected_resolutions)) if len(selected_resolutions) == 1 else None
    new_data.prices = BoxList(sorted(prices_by_start_timestamp.values(), key=lambda point: point.start_timestamp))
    if len(new_data.prices) == 0:
        raise ValueError(f"No usable ENTSO-E price points found for {area.key}.")
    if new_data.fallback_price_count > 0:
        logger.warning(
            f"Filled {new_data.fallback_price_count} {area.key} price points from fallback "
            f"ENTSO-E sequences {new_data.fallback_sequence_positions}."
        )

    return new_data


def get_data_refresh_lock(area_key: str, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing current price data."""
    lock_file_name = f"price-refresh-{prices.area_file_key(area_key)}.lock"
    return ExtendedFileLock(config.paths.price_data_dir / lock_file_name)


def get_history_data_refresh_lock(area_key: str, day: date, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing one historical day."""
    lock_file_name = f"price-history-refresh-{prices.area_file_key(area_key)}-{day.isoformat()}.lock"
    return ExtendedFileLock(config.paths.price_data_dir / lock_file_name)


def get_entsoe_query_params(
    area: MarketArea,
    period_start_local: Optional[Arrow] = None,
    period_end_local: Optional[Arrow] = None,
) -> dict[str, str]:
    """Build ENTSO-E price query parameters."""
    if period_start_local is None or period_end_local is None:
        now_local = arrow.now(area.timezone)
        period_start_local = now_local.floor("day")
        period_end_local = period_start_local.shift(days=+2)

    return {
        "documentType": "A44",
        "in_Domain": area.entsoe_domain,
        "out_Domain": area.entsoe_domain,
        "periodStart": period_start_local.to("UTC").format("YYYYMMDDHHmm"),
        "periodEnd": period_end_local.to("UTC").format("YYYYMMDDHHmm"),
    }


def get_history_period(area: MarketArea, day: date) -> tuple[Arrow, Arrow]:
    """Get the local start and end for a historical market-area day."""
    period_start = arrow.get(day.isoformat(), "YYYY-MM-DD", tzinfo=area.timezone)
    return period_start, period_start.shift(days=+1)


async def download_data(
    area: MarketArea,
    config: Config,
    period_start_local: Optional[Arrow] = None,
    period_end_local: Optional[Arrow] = None,
) -> Optional[bytes]:
    """Download price data from ENTSO-E."""
    query_params = get_entsoe_query_params(area, period_start_local, period_end_local)
    query_params["securityToken"] = config.entsoe.token_file.read_text().strip()
    logger.info(f"Polling {area.key} price data from ENTSO-E.")

    async with httpx.AsyncClient() as client:
        try:
            async for attempt in AsyncRetrying(
                before=log_attempts(logger.debug, "download ENTSO-E price data"),
                stop=(
                    stop_after_attempt(defaults.ENTSOE_RETRY_MAX_ATTEMPTS)
                    | stop_after_delay(defaults.ENTSOE_RETRY_STOP_DELAY)
                ),
                wait=wait_exponential(multiplier=1.5, min=0, max=4),
                retry=retry_if_exception_type((httpx.RequestError, httpx.HTTPStatusError)),
                reraise=True,
            ):
                with attempt:
                    response = await client.get(
                        config.entsoe.url,
                        params=query_params,
                        timeout=defaults.ENTSOE_TIMEOUT,
                    )
                    response.raise_for_status()
                    return response.content
        except httpx.HTTPStatusError as exc:
            logger.warning(f"ENTSO-E price request for {area.key} failed with HTTP {exc.response.status_code}.")
            return None
        except Exception as exc:
            logger.warning(f"ENTSO-E price request for {area.key} failed: {type(exc).__name__}.")
            return None

    return None


async def update_last_update_time(area_key: str, config: Config):
    """Set the current price refresh timestamp."""
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(prices.area_file_key(area_key))
    file_path = config.paths.price_data_dir / file_name

    await utils.async_atomic_write_text(file_path, str(arrow.now().int_timestamp))


def check_data_new(old_data: Optional[Box], new_data: Box, area: Optional[MarketArea] = None) -> bool:
    """Return true if the downloaded data contains newer price points."""
    if old_data is None or len(old_data.prices) == 0:
        return True

    old_latest = max(old_data.prices, key=lambda point: point.end_timestamp)
    new_latest = max(new_data.prices, key=lambda point: point.end_timestamp)
    if new_latest.end_timestamp > old_latest.end_timestamp:
        return True
    if new_latest.end_timestamp < old_latest.end_timestamp:
        if area is not None and has_blocked_full_day_fallback(old_data, area):
            return True
        return False

    old_point_count = prices.unique_price_point_count(old_data)
    new_point_count = prices.unique_price_point_count(new_data)
    if new_point_count > old_point_count:
        return True
    if new_point_count < old_point_count:
        return False

    old_fallback_count = prices.fallback_price_count(old_data)
    new_fallback_count = prices.fallback_price_count(new_data)
    if new_fallback_count < old_fallback_count:
        return True
    if new_fallback_count > old_fallback_count:
        return False

    return prices.price_data_signature(new_data) != prices.price_data_signature(old_data)


async def refresh_current_prices(
    stored_data: Optional[Box],
    area_key: str,
    config: Config,
    lock_timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT,
) -> Optional[Box]:
    """Download and store fresh current price data."""
    area = defaults.get_market_area(area_key)
    refresh_lock = get_data_refresh_lock(area_key, config)
    try:
        could_acquire_immediately = await acquire_file_lock_immediate(refresh_lock, timeout=lock_timeout)
    except filelock.Timeout:
        logger.debug(f"Skipping refresh for {area.key} because another refresh is already running.")
        return None

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            downloaded_data = await download_data(area, config)
            if downloaded_data is None:
                return None
            try:
                await update_last_update_time(area_key, config)
            except Exception as exc:
                logger.exception(f"Couldn't write last update time: {exc}.")
            new_data = parse_downloaded_data(area, downloaded_data)
            if not check_data_new(stored_data, new_data, area):
                return None
            await prices.store_data(new_data, area_key, config)
            return new_data

    refresh_lock.release()
    return await prices.get_stored_data(area_key, config)


async def refresh_history_prices(area_key: str, day: date, config: Config) -> Optional[Box]:
    """Download and store one historical price day."""
    area = defaults.get_market_area(area_key)
    stored_data = await prices.get_stored_history_data(area_key, day, config)
    if stored_data is not None and prices.has_complete_local_day(stored_data, area, day):
        return stored_data

    refresh_lock = get_history_data_refresh_lock(area_key, day, config)
    try:
        could_acquire_immediately = await acquire_file_lock_immediate(refresh_lock)
    except filelock.Timeout:
        return await prices.get_stored_history_data(area_key, day, config)

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            latest_stored_data = await prices.get_stored_history_data(area_key, day, config)
            if latest_stored_data is not None and prices.has_complete_local_day(latest_stored_data, area, day):
                return latest_stored_data

            new_data = await download_history_prices(area_key, day, config)
            if new_data is None:
                return latest_stored_data or stored_data

            if latest_stored_data is None or check_data_new(latest_stored_data, new_data):
                await prices.store_history_data(new_data, area_key, day, config)
                return new_data

            return latest_stored_data

    refresh_lock.release()
    return await prices.get_stored_history_data(area_key, day, config)


async def download_history_prices(area_key: str, day: date, config: Config) -> Optional[Box]:
    """Download and parse one historical price day without storing it."""
    area = defaults.get_market_area(area_key)
    period_start_local, period_end_local = get_history_period(area, day)
    downloaded_data = await download_data(area, config, period_start_local, period_end_local)
    if downloaded_data is None:
        return None

    return parse_downloaded_data(area, downloaded_data)
