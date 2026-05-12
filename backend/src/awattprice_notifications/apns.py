import arrow
import jwt

from aiofile import async_open
from box import Box
from liteconfig import Config

from awattprice_notifications import apns_defaults


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
        algorithm=apns_defaults.APNS_ENCRYPTION_ALGORITHM,
        headers=auth_jwt_headers,
    )

    return authorization
