"""Refresh ENTSO-E generation mix caches."""
import filelock
import httpx
import time

from dataclasses import dataclass
from typing import Optional

import arrow

from box import Box
from liteconfig import Config
from loguru import logger
from tenacity import (
    AsyncRetrying,
    retry_if_exception,
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


@dataclass
class GenerationRefreshResult:
    status: str
    mode: str
    metadata: Optional[Box] = None
    downloaded_bytes: int = 0
    duration_seconds: float = 0
    error: Optional[str] = None


def get_data_refresh_lock(area_key: str, config: Config) -> ExtendedFileLock:
    """Get file lock used when refreshing generation data."""
    lock_file_name = defaults.GENERATION_REFRESH_LOCK_FILE_NAME.format(area_file_key(area_key))
    return ExtendedFileLock(config.paths.generation_data_dir / lock_file_name)


def get_entsoe_query_params(
    area: MarketArea,
    hours: int,
    now: Optional[arrow.Arrow] = None,
) -> dict[str, str]:
    """Build ENTSO-E actual generation per production type query parameters."""
    now_local = (now or arrow.now(area.timezone)).to(area.timezone).floor("hour")
    period_start_local = now_local.shift(hours=-hours)
    period_end_local = now_local.shift(hours=+1)

    return {
        "documentType": "A75",
        "processType": "A16",
        "in_Domain": area.entsoe_domain,
        "periodStart": period_start_local.to("UTC").format("YYYYMMDDHHmm"),
        "periodEnd": period_end_local.to("UTC").format("YYYYMMDDHHmm"),
    }


def _retryable_entsoe_error(exc: BaseException) -> bool:
    if isinstance(exc, httpx.RequestError):
        return True
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code == 429 or exc.response.status_code >= 500
    return False


async def download_data(
    area: MarketArea,
    config: Config,
    hours: int,
    client: Optional[httpx.AsyncClient] = None,
) -> Optional[bytes]:
    """Download generation mix data from the ENTSO-E API."""
    query_params = get_entsoe_query_params(area, hours)
    query_params["securityToken"] = config.entsoe.token_file.read_text().strip()

    logger.trace(f"Polling {area.key} generation mix data from ENTSO-E ({hours}h).")

    async def request(active_client: httpx.AsyncClient) -> Optional[bytes]:
        try:
            async for attempt in AsyncRetrying(
                before=log_attempts(logger.debug, "download ENTSO-E generation mix data"),
                wait=wait_fixed(3) + wait_exponential(multiplier=1, min=2, max=10),
                stop=(
                    stop_after_attempt(defaults.ENTSOE_RETRY_MAX_ATTEMPTS)
                    | stop_after_delay(defaults.ENTSOE_RETRY_STOP_DELAY)
                ),
                retry=retry_if_exception(_retryable_entsoe_error),
                reraise=True,
            ):
                with attempt:
                    response = await active_client.get(
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
        except httpx.RequestError as exc:
            logger.warning(
                f"ENTSO-E generation mix request for {area.key} failed: "
                f"{type(exc).__name__}."
            )
        return None

    if client is not None:
        return await request(client)

    async with httpx.AsyncClient(http2=True) as owned_client:
        return await request(owned_client)

    return None


def full_refresh_due(raw_data: Optional[Box], now: arrow.Arrow) -> bool:
    """Return whether an area needs a complete generation reconciliation."""
    if raw_data is None or raw_data.get("last_full_refresh_at") is None:
        return True
    return (
        now - raw_data.last_full_refresh_at
    ).total_seconds() >= defaults.GENERATION_FULL_REFRESH_INTERVAL_SECONDS


async def refresh_generation_mix(
    stored_metadata: Optional[Box],
    area_key: str,
    config: Config,
    lock_timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT,
    client: Optional[httpx.AsyncClient] = None,
) -> GenerationRefreshResult:
    """Download and store the latest generation mix data."""
    started_at = time.monotonic()
    area = defaults.get_market_area(area_key)
    refresh_lock = get_data_refresh_lock(area_key, config)
    try:
        could_acquire_immediately = await acquire_file_lock_immediate(refresh_lock, timeout=lock_timeout)
    except filelock.Timeout:
        logger.debug(f"Skipping generation refresh for {area.key} because another refresh is running.")
        return GenerationRefreshResult(
            status="skipped",
            mode="none",
            metadata=stored_metadata,
            duration_seconds=time.monotonic() - started_at,
        )

    if could_acquire_immediately:
        with refresh_lock.context(acquire=False):
            raw_data = await generation_mix.get_stored_raw_data(
                area_key,
                defaults.GENERATION_RETENTION_HOURS,
                config,
            )
            now = arrow.now(area.timezone)
            is_full_refresh = full_refresh_due(raw_data, now)
            mode = "full" if is_full_refresh else "incremental"
            request_hours = (
                defaults.GENERATION_RETENTION_HOURS
                + defaults.GENERATION_RETENTION_SAFETY_HOURS
                if is_full_refresh
                else defaults.GENERATION_INCREMENTAL_HOURS
            )
            downloaded_data = await download_data(
                area,
                config,
                request_hours,
                client=client,
            )
            downloaded_bytes = len(downloaded_data) if downloaded_data is not None else 0
            if downloaded_data is None:
                return GenerationRefreshResult(
                    status="failed",
                    mode=mode,
                    metadata=stored_metadata,
                    downloaded_bytes=downloaded_bytes,
                    duration_seconds=time.monotonic() - started_at,
                    error="ENTSO-E request failed.",
                )
            try:
                parsed_data = generation_mix.parse_downloaded_data(area, downloaded_data)
            except ValueError as exc:
                if "No matching data found" in str(exc):
                    logger.warning(f"No ENTSO-E generation mix data available for {area.key}.")
                    status = "no_data"
                else:
                    logger.warning(f"Skipping generation mix update for {area.key}: {exc}.")
                    status = "failed"
                return GenerationRefreshResult(
                    status=status,
                    mode=mode,
                    metadata=stored_metadata,
                    downloaded_bytes=downloaded_bytes,
                    duration_seconds=time.monotonic() - started_at,
                    error=str(exc),
                )

            last_full_refresh_at = raw_data.get("last_full_refresh_at") if raw_data is not None else None
            if is_full_refresh:
                merged_data = generation_mix.retain_generation_window(
                    parsed_data,
                    defaults.GENERATION_RETENTION_HOURS,
                )
                last_full_refresh_at = now
            else:
                try:
                    merged_data = generation_mix.merge_generation_data(
                        raw_data,
                        parsed_data,
                        defaults.GENERATION_RETENTION_HOURS,
                    )
                except ValueError as exc:
                    await generation_mix.store_raw_data(
                        raw_data,
                        area_key,
                        defaults.GENERATION_RETENTION_HOURS,
                        config,
                        last_full_refresh_at=None,
                    )
                    return GenerationRefreshResult(
                        status="failed",
                        mode=mode,
                        metadata=stored_metadata,
                        downloaded_bytes=downloaded_bytes,
                        duration_seconds=time.monotonic() - started_at,
                        error=str(exc),
                    )

            history_cache_missing = not generation_mix.cache_file_present(
                generation_mix.get_history_response_data_path(
                    area_key,
                    defaults.GENERATION_RETENTION_HOURS,
                    config,
                )
            )
            published_cache_missing = not generation_mix.cache_file_present(
                generation_mix.get_published_history_response_data_path(
                    area_key,
                    defaults.GENERATION_RETENTION_HOURS,
                    config,
                )
            )

            data_changed = (
                raw_data is None
                or generation_mix.generation_data_signature(raw_data)
                != generation_mix.generation_data_signature(merged_data)
            )
            if not data_changed and not history_cache_missing and not published_cache_missing:
                if is_full_refresh:
                    await generation_mix.store_raw_data(
                        merged_data,
                        area_key,
                        defaults.GENERATION_RETENTION_HOURS,
                        config,
                        last_full_refresh_at,
                    )
                return GenerationRefreshResult(
                    status="unchanged",
                    mode=mode,
                    metadata=stored_metadata,
                    downloaded_bytes=downloaded_bytes,
                    duration_seconds=time.monotonic() - started_at,
                )

            response_data, published_response_data = generation_mix.parse_history_responses(
                merged_data,
                defaults.GENERATION_RETENTION_HOURS,
            )
            metadata = await generation_mix.store_response_data(
                merged_data,
                response_data,
                area_key,
                defaults.GENERATION_RETENTION_HOURS,
                config,
                published_response_data,
            )
            await generation_mix.store_raw_data(
                merged_data,
                area_key,
                defaults.GENERATION_RETENTION_HOURS,
                config,
                last_full_refresh_at,
            )
            return GenerationRefreshResult(
                status="updated" if data_changed else "rebuilt",
                mode=mode,
                metadata=metadata,
                downloaded_bytes=downloaded_bytes,
                duration_seconds=time.monotonic() - started_at,
            )

    refresh_lock.release()
    return GenerationRefreshResult(
        status="skipped",
        mode="none",
        metadata=await generation_mix.get_stored_metadata(area_key, config),
        duration_seconds=time.monotonic() - started_at,
    )
