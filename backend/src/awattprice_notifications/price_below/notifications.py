"""Send price below notifications."""
from awattprice.defaults import Region
from awattprice.orm import Token
from liteconfig import Config

import awattprice
import awattprice_notifications

from awattprice_notifications.price_below import defaults 
from awattprice_notifications.price_below.prices import DetailedPriceData


async def get_general_send_request_headers() -> Box:
    """Get the headers for requests sending price below notifications."""
    apns_authorization = await awattprice_notifications.apns.get_apns_request_authorization(config)

    request_headers = Box()
    request_headers.authorization = f"bearer {apns_authorization}"
    request_headers["apns-push-type"] = defaults.PRICE_BELOW_PUSH_TYPE
    request_headers["apns-topic"] = awattprice.defaults.APP_BUNDLE_ID
    request_headers["apns-priority"] = defaults.PRICE_BELOW_PRIORITY
    request_headers["apns-collapse-id"] = defaults.PRICE_BELOW_COLLAPSE_ID

    return request_headers


async def send_notifications(
    config: Config, tokens: dict[Region, list[Token]], price_data: dict[Region, DetailedPriceData]
):
    """Send price below notifications for certain tokens.

    :param tokens, price_data: Each region which has applying tokens *must* also be present in the price data.
    """

    request_headers = await get_general_send_request_headers()
    # request_headers["apns-expiration"] set per user basis
    print(request_headers)
