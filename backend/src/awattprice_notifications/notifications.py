"""Send notifications."""
import awattprice
import httpx

from awattprice.orm import Token
from box import Box
from loguru import logger

from tenacity import AsyncRetrying, retry_if_exception_type, stop_after_attempt, stop_after_delay, wait_exponential, wait_fixed

from awattprice_notifications import defaults

async def send_notification(
    client: httpx.AsyncClient, token: Token, headers: Box, notification: Box, use_sandbox=False
) -> httpx.Response:
    """Send a single notification."""
    if use_sandbox is True:
        origin = defaults.APNS_URL.origin.sandbox
    else:
        origin = defaults.APNS_URL.origin.production
    path = defaults.APNS_URL.path
    path = path.format(token.token)

    url = origin + path

    timeout = defaults.APNS_TIMEOUT
    attempts = defaults.APNS_ATTEMPTS
    stop_delay = defaults.APNS_STOP_DELAY
    async for attempt in AsyncRetrying(
        before=awattprice.utils.log_attempts(logger.debug),
        retry=retry_if_exception_type((httpx.TimeoutException, httpx.NetworkError,)),
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