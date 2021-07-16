"""Send price below notifications."""
import awattprice

from awattprice.defaults import Region
from awattprice.orm import Token
from box import Box
from liteconfig import Config

import awattprice_notifications

from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below.prices import DetailedPriceData


async def get_general_send_request_headers(config: Config) -> Box:
    """Get the headers for requests sending price below notifications."""
    apns_authorization = await awattprice_notifications.apns.get_apns_request_authorization(config)

    request_headers = Box()
    request_headers.authorization = f"bearer {apns_authorization}"
    request_headers["apns-push-type"] = defaults.NOTIFICATION.PUSH_TYPE
    request_headers["apns-topic"] = awattprice.defaults.APP_BUNDLE_ID
    request_headers["apns-priority"] = defaults.NOTIFICATION.PRIORITY
    request_headers["apns-collapse-id"] = defaults.NOTIFICATION.COLLAPSE_ID

    return request_headers


def construct_token_notification(token: Token) -> Box:
    """Construct the notification for a single token."""
    notification = Box()
    notification.aps = {}
    notification.aps.alert = {}
    notification.aps.alert["title-loc-key"] = defaults.NOTIFICATION.TITLE_LOC_KEY
    notification.aps.alert["loc-key"] = defaults.NOTIFICATION.LOC_KEY
    notification.aps.alert["loc-args"] = []
    notification.aps.badge = 0
    notification.aps.sound = defaults.NOTIFICATION.SOUND
    notification.aps["content-available"] = 0

    return notification


async def send_notifications(
    config: Config, regions_tokens: dict[Region, list[Token]], price_data: dict[Region, DetailedPriceData]
):
    """Send price below notifications for certain tokens.

    :param tokens, price_data: Each region which has applying tokens *must* also be present in the price data.
    """

    request_headers = await get_general_send_request_headers(config)

    for region, tokens in regions_tokens.items():
        for token in tokens:
            notification = construct_token_notification(token)
            print(notification)
            # request_headers["apns-expiration"] set per user basis
