"""Poll and process generation mix data."""
import asyncio
import pickle
import xml.etree.ElementTree as ET

from decimal import Decimal
from typing import Optional

import arrow
import filelock
import httpx

from aiofile import async_open
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
    wait_fixed,
)

from awattprice import defaults
from awattprice.market_areas import MarketArea
from awattprice.prices import area_file_key
from awattprice.prices import resolution_to_seconds
from awattprice.utils import ExtendedFileLock
from awattprice.utils import log_attempts


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


async def get_last_update_time(area_key: str, config: Config) -> Optional[Arrow]:
    """Get time the generation data was updated last."""
    file_dir = config.paths.generation_data_dir
    file_name = defaults.GENERATION_DATA_UPDATE_TS_FILE_NAME.format(area_file_key(area_key))
    file_path = file_dir / file_name

    try:
        async with async_open(file_path, "r") as file:
            file_content = await file.read()
    except FileNotFoundError:
        return None

    return arrow.get(int(file_content))


def check_update_data(data: Optional[Box], last_update_time: Optional[Arrow], area: MarketArea) -> bool:
    """Check if generation data should be refreshed."""
    if data is None or len(data.generation_points) == 0:
        return True

    now_local = arrow.now(area.timezone)
    if last_update_time is not None:
        next_update_time = last_update_time.shift(seconds=defaults.ENTSOE_GENERATION_COOLDOWN_INTERVAL)
        if now_local < next_update_time:
            return False

    latest_point = max(data.generation_points, key=lambda point: point.end_timestamp)
    return latest_point.end_timestamp < now_local.shift(minutes=-30)


def get_data_refresh_lock(area_key: str, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing generation data."""
    lock_file_name = defaults.GENERATION_DATA_FILE_NAME.format(area_file_key(area_key)) + ".lock"
    return ExtendedFileLock(config.paths.generation_data_dir / lock_file_name)


async def acquire_refresh_lock_immediate(
    lock: ExtendedFileLock, timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT
) -> bool:
    """Acquire the refresh lock either immediately or with waiting."""
    async_acquire = asyncio.to_thread
    try:
        await async_acquire(lock.acquire, timeout=0)
    except filelock.Timeout:
        pass
    else:
        return True

    if timeout <= 0:
        raise filelock.Timeout(lock.lock_file)

    try:
        await async_acquire(lock.acquire, timeout=timeout)
    except filelock.Timeout:
        raise
    else:
        return False


def get_entsoe_query_params(area: MarketArea) -> dict[str, str]:
    """Build ENTSO-E query parameters for actual generation per production type."""
    now_local = arrow.now(area.timezone)
    period_start_local = now_local.shift(hours=-24)
    period_end_local = now_local.shift(hours=+1)

    return {
        "documentType": "A75",
        "processType": "A16",
        "in_Domain": area.entsoe_domain,
        "periodStart": period_start_local.to("UTC").format("YYYYMMDDHHmm"),
        "periodEnd": period_end_local.to("UTC").format("YYYYMMDDHHmm"),
    }


async def download_data(area: MarketArea, config: Config) -> Optional[bytes]:
    """Download generation mix data from the ENTSO-E API."""
    url = config.entsoe.url
    token = config.entsoe.token_file.read_text().strip()
    query_params = get_entsoe_query_params(area)
    query_params["securityToken"] = token

    logger.info(f"Polling {area.key} generation mix data from ENTSO-E.")
    try:
        async for attempt in AsyncRetrying(
            before=log_attempts(logger.debug, "download ENTSO-E generation mix data"),
            wait=wait_fixed(3) + wait_exponential(multiplier=1, min=2, max=10),
            stop=(stop_after_attempt(defaults.ENTSOE_RETRY_MAX_ATTEMPTS) | stop_after_delay(defaults.ENTSOE_RETRY_STOP_DELAY)),
            retry=retry_if_exception_type(httpx.RequestError),
            reraise=True,
        ):
            with attempt:
                async with httpx.AsyncClient(http2=True) as client:
                    response = await client.get(url, params=query_params, timeout=defaults.ENTSOE_TIMEOUT)
                    response.raise_for_status()
                    return response.content
    except httpx.RequestError as exc:
        logger.exception(f"Requests failed when downloading generation mix data: {exc}.")
        return None

    return None


async def update_last_update_time(area_key: str, config: Config):
    """Set the generation data update timestamp to now."""
    file_name = defaults.GENERATION_DATA_UPDATE_TS_FILE_NAME.format(area_file_key(area_key))
    file_path = config.paths.generation_data_dir / file_name

    async with async_open(file_path, "w") as file:
        await file.write(str(arrow.now().int_timestamp))


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
    new_data.generation_points = BoxList()

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
                new_data.generation_points.append(generation_point)

    new_data.resolution = selected_resolution
    new_data.generation_points = BoxList(sorted(new_data.generation_points, key=lambda point: point.start_timestamp))
    if len(new_data.generation_points) == 0:
        raise ValueError(f"No usable ENTSO-E generation points found for {area.key}.")

    return new_data


def check_data_new(old_data: Optional[Box], new_data: Box) -> bool:
    """Check if downloaded generation data has a newer interval."""
    if old_data is None or len(old_data.generation_points) == 0:
        return True

    old_latest = max(old_data.generation_points, key=lambda point: point.end_timestamp)
    new_latest = max(new_data.generation_points, key=lambda point: point.end_timestamp)
    return new_latest.end_timestamp > old_latest.end_timestamp


async def store_data(data: Box, area_key: str, config: Config):
    """Store generation data to the filesystem."""
    file_name = defaults.GENERATION_DATA_FILE_NAME.format(area_file_key(area_key))
    file_path = config.paths.generation_data_dir / file_name

    logger.info(f"Storing ENTSO-E {area_key} generation data to {file_path}.")
    async with async_open(file_path, "wb") as file:
        await file.write(pickle.dumps(data))


async def get_latest_new_generation_mix(
    stored_data: Optional[Box],
    area_key: str,
    config: Config,
    lock_timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT,
) -> Optional[Box]:
    """Download the latest generation mix data."""
    area = defaults.get_market_area(area_key)
    refresh_lock = get_data_refresh_lock(area_key, config)
    try:
        could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock, timeout=lock_timeout)
    except filelock.Timeout:
        logger.debug(f"Skipping generation refresh for {area.key} because another refresh is running.")
        return None

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            downloaded_data = await download_data(area, config)
            if downloaded_data is None:
                return None
            new_data = parse_downloaded_data(area, downloaded_data)
            try:
                await update_last_update_time(area_key, config)
            except Exception as exc:
                logger.exception(f"Couldn't write generation update time: {exc}.")
            if not check_data_new(stored_data, new_data):
                return None
            await store_data(new_data, area_key, config)
            return new_data

    refresh_lock.release()
    return await get_stored_data(area_key, config)


async def get_current_generation_mix(area_key: str, config: Config, fall_back: bool = True) -> Optional[Box]:
    """Get current generation mix data."""
    area = defaults.get_market_area(area_key)
    stored_data, last_update_time = await asyncio.gather(
        get_stored_data(area_key, config),
        get_last_update_time(area_key, config),
        return_exceptions=True,
    )
    if isinstance(stored_data, Exception):
        logger.exception(f"Couldn't get stored {area.key} generation data: {stored_data}.")
        stored_data = None
    if isinstance(last_update_time, Exception):
        logger.exception(f"Couldn't get stored {area.key} generation update time: {last_update_time}.")
        last_update_time = None

    if check_update_data(stored_data, last_update_time, area):
        try:
            generation_data = await get_latest_new_generation_mix(stored_data, area_key, config)
        except Exception as exc:
            logger.exception(f"Couldn't get latest generation mix for area {area.key}: {exc}.")
            generation_data = stored_data if fall_back else None
        if generation_data is None and fall_back:
            generation_data = stored_data
        return generation_data

    return stored_data


def latest_interval_points(generation_data: Box) -> BoxList:
    """Return generation points for the latest interval with a representative production mix."""
    points_by_end = {}
    for point in generation_data.generation_points:
        points_by_end.setdefault(point.end_timestamp, BoxList()).append(point)

    best_production_type_count = max(
        len({point.raw_production_type for point in points if point.raw_production_type is not None})
        for points in points_by_end.values()
    )

    usable_end_times = [
        end_timestamp
        for end_timestamp, points in points_by_end.items()
        if len({point.raw_production_type for point in points if point.raw_production_type is not None})
        == best_production_type_count
    ]
    latest_usable_end = max(usable_end_times)
    return points_by_end[latest_usable_end]


def parse_to_response_data(generation_data: Box) -> Box:
    """Parse cached generation data to the narrow app response."""
    points = latest_interval_points(generation_data)
    categories = {category: Decimal("0") for category in GENERATION_CATEGORIES}
    for point in points:
        quantity_mw = max(point.quantity_mw, Decimal("0"))
        categories[point.category] = categories.get(point.category, Decimal("0")) + quantity_mw

    total_mw = sum(categories.values(), Decimal("0"))
    renewable_mw = sum(max(point.quantity_mw, Decimal("0")) for point in points if point.is_renewable)

    response = Box()
    response.source = generation_data.source
    response.area = generation_data.area
    response.display_name = generation_data.display_name
    response.entsoe_domain = generation_data.entsoe_domain
    response.timezone = generation_data.timezone
    response.resolution = generation_data.resolution
    response.updated_at = generation_data.updated_at.int_timestamp
    response.start_timestamp = min(point.start_timestamp for point in points).int_timestamp
    response.end_timestamp = max(point.end_timestamp for point in points).int_timestamp
    response.total_generation_mw = float(total_mw)
    response.renewable_generation_mw = float(renewable_mw)
    response.renewable_share = float((renewable_mw / total_mw) * 100) if total_mw > 0 else 0.0
    response.categories = []

    for category in GENERATION_CATEGORIES:
        quantity_mw = categories[category]
        category_response = Box()
        category_response.category = category
        category_response.generation_mw = float(quantity_mw)
        category_response.share = float((quantity_mw / total_mw) * 100) if total_mw > 0 else 0.0
        category_response.is_renewable = category in RENEWABLE_CATEGORIES
        response.categories.append(category_response)

    return response
