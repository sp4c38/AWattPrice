"""Poll and process price data."""
import asyncio
import pickle
import xml.etree.ElementTree as ET

from datetime import date
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
from awattprice import utils
from awattprice.market_areas import MarketArea
from awattprice.utils import ExtendedFileLock
from awattprice.utils import log_attempts

_background_refresh_tasks: dict[str, asyncio.Task] = {}


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
    return defaults.normalize_market_area_key(area_key).lower()


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


async def get_last_update_time(area_key: str, config: Config) -> Optional[Arrow]:
    """Get time the price data was updated last.

    :returns None: If file not found.
    :returns arrow.Arrow: Last update time.
    """
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(area_file_key(area_key))
    file_path = file_dir / file_name

    try:
        async with async_open(file_path, "r") as file:
            file_content = await file.read()
    except FileNotFoundError:
        return None

    timestamp = int(file_content)
    time = arrow.get(timestamp)

    return time


def check_update_data(data: Optional[Box], last_update_time: Optional[Arrow], area: MarketArea) -> bool:
    """Check if price data is due for update.

    :param last_update_time: Time data was last polled from the ENTSO-E API.
    :returns: True if data is due, false if not due.
    """
    if data is None:
        return True
    if len(data.prices) == 0:
        return True

    now_local = arrow.now(area.timezone)
    if not has_current_price_points(data, area):
        logger.debug(f"Stored {area.key} data has no current prices.")
        return True

    if last_update_time is not None:
        next_update_time = last_update_time.shift(seconds=defaults.ENTSOE_COOLDOWN_INTERVAL)
        if now_local < next_update_time:
            seconds_remaining = (next_update_time - now_local).total_seconds()
            logger.debug(f"ENTSO-E cooldown has {seconds_remaining}s remaining.")
            return False

    midnight_tomorrow_local = now_local.floor("day").shift(days=+2)
    latest_price = max(data.prices, key=lambda point: point.end_timestamp)
    if latest_price.end_timestamp >= midnight_tomorrow_local:
        logger.debug("Price points still available until tomorrow midnight.")
        return False

    midnight_today_local = now_local.floor("day").shift(days=+1)
    if latest_price.end_timestamp < midnight_today_local:
        return True

    if now_local.hour < defaults.ENTSOE_UPDATE_HOUR:
        logger.debug(f"Not past update hour ({defaults.ENTSOE_UPDATE_HOUR}).")
        return False

    return True


def has_current_price_points(data: Optional[Box], area: MarketArea) -> bool:
    """Check if cached data contains prices the app can still display."""
    if data is None:
        return False

    now_local = arrow.now(area.timezone)
    return any(price_point.end_timestamp > now_local for price_point in data.prices)


def get_data_refresh_lock(area_key: str, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing price data."""
    lock_dir = config.paths.price_data_dir
    lock_file_name = defaults.PRICE_DATA_FILE_NAME.format(area_file_key(area_key)) + ".lock"
    lock_file_path = lock_dir / lock_file_name
    lock = ExtendedFileLock(lock_file_path)
    return lock


async def acquire_refresh_lock_immediate(
    lock: ExtendedFileLock, timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT
) -> bool:
    """Acquire the refresh lock either immediately or with waiting.

    :returns: As soon as lock was acquired.
    :returns True: Acquired lock immediately.
    :returns False: Acquired lock after waiting.
    :raises filelock.Timeout: Lock couldn't be acquired - even after waiting.
    """
    async_acquire = utils.async_wrap(lock.acquire)
    try:
        await async_acquire(timeout=0)
    except filelock.Timeout:
        # Lock couldn't be acquired immediately.
        pass
    else:
        logger.debug("Lock acquired immediately.")
        return True

    if timeout <= 0:
        raise filelock.Timeout(lock.lock_file)

    try:
        await async_acquire(timeout=timeout)
    except filelock.Timeout as exc:
        logger.warning(f"Lock couldn't be acquired within {timeout}s: {exc}.")
        raise
    else:
        logger.debug("Lock acquired after waiting.")
        return False


def get_entsoe_query_params(
    area: MarketArea,
    period_start_local: Optional[Arrow] = None,
    period_end_local: Optional[Arrow] = None,
) -> dict[str, str]:
    """Build ENTSO-E query parameters for an area and local period."""
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


async def download_data(
    area: MarketArea,
    config: Config,
    period_start_local: Optional[Arrow] = None,
    period_end_local: Optional[Arrow] = None,
) -> Optional[bytes]:
    """Download price data from the ENTSO-E API."""
    url = config.entsoe.url
    token = config.entsoe.token_file.read_text().strip()
    query_params = get_entsoe_query_params(area, period_start_local, period_end_local)
    query_params["securityToken"] = token
    logger.info(f"Polling {area.key} price data from ENTSO-E.")


    async with httpx.AsyncClient() as client:
        try:
            async for attempt in AsyncRetrying(
                before=log_attempts(logger.debug, "download ENTSO-E price data"),
                stop=(
                    stop_after_attempt(defaults.ENTSOE_RETRY_MAX_ATTEMPTS)
                    | stop_after_delay(defaults.ENTSOE_RETRY_STOP_DELAY)
                ),
                wait=wait_exponential(multiplier=1.5, min=0, max=4)
            ):
                with attempt:
                    response = await client.get(url, params=query_params, timeout=defaults.ENTSOE_TIMEOUT)
                    response.raise_for_status()
        except Exception as exc:
            logger.exception(f"Requests - also after retrying -  failed when downloading price data: {exc}.")
            return None

    return response.content


async def update_last_update_time(area_key: str, config: Config):
    """Set the time the price data was updated last to the current time."""
    file_dir = config.paths.price_data_dir
    file_name = defaults.PRICE_DATA_UPDATE_TS_FILE_NAME.format(area_file_key(area_key))
    file_path = file_dir / file_name

    now = arrow.now()
    now_string = str(now.int_timestamp)
    async with async_open(file_path, "w") as file:
        await file.write(now_string)


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


def check_data_new(old_data: Optional[Box], new_data: Box) -> bool:
    """Check if new price points were added relative to the max price point of the old price data."""
    if old_data is None:
        return True
    if len(old_data.prices) == 0:
        return True

    max_end_compare_key = lambda point: point.end_timestamp
    max_end_old = max(old_data.prices, key=max_end_compare_key)
    max_end_new = max(new_data.prices, key=max_end_compare_key)

    if max_end_new.end_timestamp > max_end_old.end_timestamp:
        return True
    else:
        return False


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


def get_history_data_refresh_lock(area_key: str, day: date, config: Config) -> ExtendedFileLock:
    """Get file lock used when downloading one historical day."""
    lock_file_path = get_history_data_path(area_key, day, config).with_suffix(".pickle.lock")
    return ExtendedFileLock(lock_file_path)


async def get_latest_new_prices(
    stored_data: Optional[Box],
    area_key: str,
    config: Config,
    lock_timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT,
) -> Optional[Box]:
    """Download the latest new prices.

    :returns downloaded price data: If all went well.
    :returns None: There are no latest new prices.
    """
    area = defaults.get_market_area(area_key)
    refresh_lock = get_data_refresh_lock(area_key, config)
    try:
        could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock, timeout=lock_timeout)
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
                # Not ideal, but also not essential to provide the latest new prices.
            new_data = parse_downloaded_data(area, downloaded_data)
            data_is_new = check_data_new(stored_data, new_data)
            if not data_is_new:
                logger.debug(f"Downloaded data for area {area.key} includes no new prices.")
                return None
            else:
                logger.debug(f"Got fresh new data for area {area.key}.")
            await store_data(new_data, area_key, config)
            latest_prices = new_data
    else:
        refresh_lock.release()
        latest_prices = await get_stored_data(area_key, config)

    return latest_prices


def _finalize_background_refresh(area_key: str, refresh_task: asyncio.Task):
    """Clean up background refresh bookkeeping."""
    active_task = _background_refresh_tasks.get(area_key)
    if active_task is refresh_task:
        _background_refresh_tasks.pop(area_key, None)

    try:
        refresh_task.result()
    except Exception as exc:
        logger.exception(f"Background refresh for {area_key} failed: {exc}.")


def schedule_background_refresh(stored_data: Optional[Box], area_key: str, config: Config):
    """Start a background refresh unless one is already running for the area."""
    existing_task = _background_refresh_tasks.get(area_key)
    if existing_task is not None and not existing_task.done():
        logger.debug(f"Background refresh for {area_key} is already running.")
        return

    async def run_refresh():
        refreshed_data = await get_latest_new_prices(stored_data, area_key, config, lock_timeout=0)
        if refreshed_data is not None:
            logger.debug(f"Background refresh finished for {area_key}.")

    refresh_task = asyncio.create_task(run_refresh(), name=f"awattprice-refresh-{area_key}")
    _background_refresh_tasks[area_key] = refresh_task
    refresh_task.add_done_callback(lambda finished_task: _finalize_background_refresh(area_key, finished_task))
    logger.debug(f"Scheduled background refresh for {area_key}.")


async def get_current_prices(
    area_key: str,
    config: Config,
    fall_back: bool = False,
    background_refresh: bool = False,
) -> Optional[dict]:
    """Get the currently up to date price data.

    :param fall_back: If true function will fall back to the stored data in certain situations when an
        error retrieving the actual current prices occurrs. If false none will be returned in such cases.
    :param background_refresh: If true stale cached data is returned immediately and refresh is scheduled
        in the background, but only when the cached data still contains currently displayable prices.
        If no usable cached data exists yet, the refresh still happens synchronously.
    """
    area = defaults.get_market_area(area_key)
    stored_data, last_update_time = await asyncio.gather(
        get_stored_data(area_key, config),
        get_last_update_time(area_key, config),
        return_exceptions=True,
    )
    if isinstance(stored_data, Exception):
        logger.exception(f"Couldn't get stored {area.key} data: {stored_data}.")
        return None
    if isinstance(last_update_time, Exception):
        logger.exception(
            f"Couldn't get the {area.key} last update time and thus will assume it is none: {last_update_time}."
        )
        last_update_time = None

    do_update_data = check_update_data(stored_data, last_update_time, area)
    price_data = None
    if do_update_data:
        if background_refresh and has_current_price_points(stored_data, area):
            schedule_background_refresh(stored_data, area_key, config)
            return stored_data

        if background_refresh and stored_data is not None:
            logger.debug(f"Stored {area.key} data has no current prices; waiting for refresh.")

        try:
            price_data = await get_latest_new_prices(stored_data, area_key, config)
        except Exception as exc:
            logger.exception(f"Couldn't get latest new {area.key} prices: {exc}.")
            if not fall_back:
                return None
            price_data = stored_data if has_current_price_points(stored_data, area) else None
        else:
            if price_data is None:
                logger.debug(f"No latest new price data for area {area.key}.")
                if not fall_back:
                    return None
                price_data = stored_data if has_current_price_points(stored_data, area) else None
    else:
        logger.debug(f"Local {area.key} prices still up to date.")
        price_data = stored_data

    return price_data


async def get_history_prices(area_key: str, day: date, config: Config) -> Optional[Box]:
    """Get cached or downloaded price data for a historical local day."""
    area = defaults.get_market_area(area_key)
    stored_data = await get_stored_history_data(area_key, day, config)
    if stored_data is not None:
        return stored_data

    get_history_data_dir(config).mkdir(parents=True, exist_ok=True)
    refresh_lock = get_history_data_refresh_lock(area_key, day, config)
    try:
        could_acquire_immediately = await acquire_refresh_lock_immediate(refresh_lock)
    except filelock.Timeout:
        logger.debug(f"Skipping history refresh for {area.key} {day} because another refresh is already running.")
        return await get_stored_history_data(area_key, day, config)

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            stored_data = await get_stored_history_data(area_key, day, config)
            if stored_data is not None:
                return stored_data

            period_start_local, period_end_local = get_history_period(area, day)
            downloaded_data = await download_data(area, config, period_start_local, period_end_local)
            if downloaded_data is None:
                return None

            new_data = parse_downloaded_data(area, downloaded_data)
            await store_history_data(new_data, area_key, day, config)
            return new_data

    refresh_lock.release()
    return await get_stored_history_data(area_key, day, config)


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
