"""Refresh ENTSO-E generation mix caches."""
import filelock
import httpx

from typing import Optional

import arrow

from box import Box
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
from awattprice import generation_mix
from awattprice.prices import area_file_key
from awattprice.utils import ExtendedFileLock
from awattprice.utils import acquire_file_lock_immediate
from awattprice.utils import log_attempts
from awattprice.market_areas import MarketArea


def get_data_refresh_lock(area_key: str, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing generation data."""
    lock_file_name = defaults.GENERATION_REFRESH_LOCK_FILE_NAME.format(area_file_key(area_key))
    return ExtendedFileLock(config.paths.generation_data_dir / lock_file_name)


def get_entsoe_query_params(area: MarketArea) -> dict[str, str]:
    """Build ENTSO-E actual generation per production type query parameters."""
    now_local = arrow.now(area.timezone)
    period_start_local = now_local.shift(hours=-168)
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
    query_params = get_entsoe_query_params(area)
    query_params["securityToken"] = config.entsoe.token_file.read_text().strip()

    logger.info(f"Polling {area.key} generation mix data from ENTSO-E.")
    try:
        async for attempt in AsyncRetrying(
            before=log_attempts(logger.debug, "download ENTSO-E generation mix data"),
            wait=wait_fixed(3) + wait_exponential(multiplier=1, min=2, max=10),
            stop=(stop_after_attempt(defaults.ENTSOE_RETRY_MAX_ATTEMPTS) | stop_after_delay(defaults.ENTSOE_RETRY_STOP_DELAY)),
            retry=retry_if_exception_type((httpx.RequestError, httpx.HTTPStatusError)),
            reraise=True,
        ):
            with attempt:
                async with httpx.AsyncClient(http2=True) as client:
                    response = await client.get(
                        config.entsoe.url,
                        params=query_params,
                        timeout=defaults.ENTSOE_TIMEOUT,
                    )
                    response.raise_for_status()
                    return response.content
    except httpx.HTTPStatusError as exc:
        logger.warning(
            f"ENTSO-E generation mix request for {area.key} failed with "
            f"HTTP {exc.response.status_code}."
        )
        return None
    except httpx.RequestError as exc:
        logger.warning(f"ENTSO-E generation mix request for {area.key} failed: {type(exc).__name__}.")
        return None

    return None


def check_data_new(old_metadata: Optional[Box], new_metadata: Box) -> bool:
    """Check if downloaded generation data has a newer interval."""
    if old_metadata is None:
        return True

    return new_metadata.latest_generation_end > old_metadata.latest_generation_end


async def refresh_generation_mix(
    stored_metadata: Optional[Box],
    area_key: str,
    config: Config,
    lock_timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT,
) -> Optional[Box]:
    """Download and store the latest generation mix data."""
    area = defaults.get_market_area(area_key)
    refresh_lock = get_data_refresh_lock(area_key, config)
    try:
        could_acquire_immediately = await acquire_file_lock_immediate(refresh_lock, timeout=lock_timeout)
    except filelock.Timeout:
        logger.debug(f"Skipping generation refresh for {area.key} because another refresh is running.")
        return None

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            downloaded_data = await download_data(area, config)
            if downloaded_data is None:
                return None
            try:
                new_data = generation_mix.parse_downloaded_data(area, downloaded_data)
            except ValueError as exc:
                logger.warning(f"Skipping generation mix update for {area.key}: {exc}.")
                return None
            response_data = generation_mix.parse_to_history_response_data(
                new_data,
                hours=defaults.GENERATION_RETENTION_HOURS,
            )
            new_metadata = generation_mix.metadata_from_response_data(
                new_data,
                response_data,
                defaults.GENERATION_RETENTION_HOURS,
            )
            if not check_data_new(stored_metadata, new_metadata):
                return None
            return await generation_mix.store_response_data(
                new_data,
                response_data,
                area_key,
                defaults.GENERATION_RETENTION_HOURS,
                config,
            )

    refresh_lock.release()
    return await generation_mix.get_stored_metadata(area_key, config)
