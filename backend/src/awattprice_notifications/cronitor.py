"""Best-effort Cronitor telemetry for notification worker runs."""
import socket
from typing import Optional

import httpx
from liteconfig import Config
from loguru import logger

TELEMETRY_URL_TEMPLATE = "https://cronitor.link/p/{api_key}/{monitor_key}"
TIMEOUT = 5


def is_enabled(config: Config) -> bool:
    """Return whether Cronitor telemetry has the required credentials."""
    return bool(
        getattr(config.cronitor, "api_key", None)
        and getattr(config.cronitor, "monitor_key", None)
    )


def require_configured(config: Config):
    """Raise if Cronitor is not configured for the notification worker."""
    if not is_enabled(config):
        raise RuntimeError("Cronitor must be configured for the notifications worker.")


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
) -> bool:
    """Send one Cronitor event, returning false if disabled or unavailable."""
    require_configured(config)

    url = TELEMETRY_URL_TEMPLATE.format(api_key=config.cronitor.api_key, monitor_key=config.cronitor.monitor_key)
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

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            await client.get(url, params=params)
    except Exception as exc:
        logger.warning(f"Couldn't send Cronitor {state} event: {exc}.")
        return False

    return True
