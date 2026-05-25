"""Authorize and send Apple Push Notification service requests."""
import arrow
import httpx
import jwt

from aiofile import async_open
from awattprice import utils as awattprice_utils
from box import Box
from liteconfig import Config
from loguru import logger
from tenacity import (
    AsyncRetrying,
    retry_if_exception_type,
    stop_after_attempt,
    stop_after_delay,
    wait_exponential,
)

NOTIFICATIONS_SERVICE_NAME = "notifications"

APNS_ENCRYPTION_ALGORITHM = "ES256"
APNS_URL = Box()
APNS_URL.origin = "https://api.push.apple.com:443"
APNS_URL.path = "/3/device/{}"
APNS_TIMEOUT = 15
APNS_ATTEMPTS = 3
APNS_STOP_DELAY = 30


async def get_apns_authorization(config: Config) -> str:
    """Get the jwt to authenticate for an apns request."""
    auth_jwt_headers = Box()
    auth_jwt_headers.kid = config.apns.key_id

    auth_jwt_body = Box()
    auth_jwt_body.iss = config.apns.team_id
    now = arrow.now()
    auth_jwt_body.iat = now.int_timestamp

    async with async_open(config.apns.key_file, "r") as afp:
        encryption_key = await afp.read()

    authorization = jwt.encode(
        auth_jwt_body,
        encryption_key,
        algorithm=APNS_ENCRYPTION_ALGORITHM,
        headers=auth_jwt_headers,
    )

    return authorization


async def send_notification(client: httpx.AsyncClient, token: Box, headers: Box, notification: Box) -> httpx.Response:
    """Send a single notification."""
    url = APNS_URL.origin + APNS_URL.path.format(token.token)

    async for attempt in AsyncRetrying(
        before=awattprice_utils.log_attempts(logger.debug, "send notification"),
        retry=retry_if_exception_type(
            (
                httpx.TimeoutException,
                httpx.NetworkError,
            )
        ),
        wait=wait_exponential(multiplier=1.5, min=4, max=10),
        stop=(stop_after_attempt(APNS_ATTEMPTS) | stop_after_delay(APNS_STOP_DELAY)),
        reraise=True,
    ):
        with attempt:
            try:
                response = await client.post(
                    url,
                    json=notification.to_dict(),
                    headers=headers.to_dict(),
                    timeout=APNS_TIMEOUT,
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
