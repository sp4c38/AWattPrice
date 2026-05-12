"""Send notifications."""
import httpx

from awattprice import utils as awattprice_utils
from box import Box
from loguru import logger

from tenacity import (
    AsyncRetrying,
    retry_if_exception_type,
    stop_after_attempt,
    stop_after_delay,
    wait_exponential,
    wait_fixed,
)

from awattprice_notifications import apns_defaults


async def send_notification(client: httpx.AsyncClient, token: Box, headers: Box, notification: Box) -> httpx.Response:
    """Send a single notification."""
    origin = apns_defaults.APNS_URL.origin
    path = apns_defaults.APNS_URL.path
    path = path.format(token.token)

    url = origin + path

    timeout = apns_defaults.APNS_TIMEOUT
    attempts = apns_defaults.APNS_ATTEMPTS
    stop_delay = apns_defaults.APNS_STOP_DELAY
    async for attempt in AsyncRetrying(
        before=awattprice_utils.log_attempts(logger.debug, "send notification"),
        retry=retry_if_exception_type(
            (
                httpx.TimeoutException,
                httpx.NetworkError,
            )
        ),
        wait=wait_exponential(multiplier=1.5, min=4, max=10),
        stop=(stop_after_attempt(attempts) | stop_after_delay(stop_delay)),
        reraise=True,
    ):
        with attempt:
            try:
                response = await client.post(
                    url, json=notification.to_dict(), headers=headers.to_dict(), timeout=timeout
                )
            except httpx.TimeoutException as exc:
                logger.exception(f"Timed out when sending notification: {exc}.")
                raise
            except httpx.NetworkError as exc:
                logger.exception(f"Network error when sending notification: {exc}.")
                raise
            except Exception as exc:
                logger.exception(f"Unexpected exception when sending notification: {exc}.")
                raise

    return response
