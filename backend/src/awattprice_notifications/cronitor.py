"""Best-effort Cronitor telemetry for notification worker runs."""
import asyncio
import socket
from typing import Optional

import httpx
from liteconfig import Config
from loguru import logger

TELEMETRY_URL_TEMPLATE = "https://cronitor.link/p/{api_key}/{monitor_key}"
TIMEOUT = 5
ATTEMPTS = 3
RETRY_DELAY = 1


def _monitor_key(config: Config, monitor_key: Optional[str] = None) -> Optional[str]:
    return monitor_key or getattr(config.cronitor, "monitor_key", None)


def is_enabled(config: Config, monitor_key: Optional[str] = None) -> bool:
    """Return whether Cronitor telemetry has the required credentials."""
    return bool(
        getattr(config.cronitor, "api_key", None)
        and _monitor_key(config, monitor_key)
    )


def require_configured(config: Config, monitor_key: Optional[str] = None, service_name: str = "worker"):
    """Raise if Cronitor is not configured for a worker."""
    if not is_enabled(config, monitor_key):
        raise RuntimeError(f"Cronitor must be configured for the {service_name}.")


def build_params(
    config: Config,
    state: str,
    series: str,
    message: Optional[str] = None,
    duration: Optional[float] = None,
    count: Optional[int] = None,
    error_count: Optional[int] = None,
    status_code: Optional[int] = None,
) -> list[tuple[str, str]]:
    """Build Cronitor telemetry query parameters."""
    params = [
        ("state", state),
        ("series", series),
        ("host", socket.gethostname()),
    ]

    if getattr(config.cronitor, "environment", None):
        params.append(("env", str(config.cronitor.environment)))
    if message:
        params.append(("message", message[:2000]))
    if duration is not None:
        params.append(("metric", f"duration:{duration:.3f}"))
    if count is not None:
        params.append(("metric", f"count:{count}"))
    if error_count is not None:
        params.append(("metric", f"error_count:{error_count}"))
    if status_code is not None:
        params.append(("status_code", str(status_code)))

    return params


async def send_event(
    config: Config,
    state: str,
    series: str,
    message: Optional[str] = None,
    duration: Optional[float] = None,
    count: Optional[int] = None,
    error_count: Optional[int] = None,
    status_code: Optional[int] = None,
    monitor_key: Optional[str] = None,
) -> bool:
    """Send one Cronitor event, returning false if disabled or unavailable."""
    resolved_monitor_key = _monitor_key(config, monitor_key)
    require_configured(config, resolved_monitor_key)

    url = TELEMETRY_URL_TEMPLATE.format(api_key=config.cronitor.api_key, monitor_key=resolved_monitor_key)
    params = build_params(
        config,
        state,
        series,
        message=message,
        duration=duration,
        count=count,
        error_count=error_count,
        status_code=status_code,
    )

    for attempt in range(1, ATTEMPTS + 1):
        try:
            async with httpx.AsyncClient(timeout=TIMEOUT) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
            return True
        except Exception as exc:
            if attempt == ATTEMPTS:
                logger.warning(f"Couldn't send Cronitor {state} event: {exc}.")
                return False
            await asyncio.sleep(RETRY_DELAY)

    return False
