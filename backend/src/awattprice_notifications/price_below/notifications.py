"""Send price below notifications."""
import awattprice

from awattprice.defaults import Region
from awattprice.orm import Token
from box import Box
from liteconfig import Config

import awattprice_notifications

from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below.prices import DetailedPriceData


def construct_notification_headers(apns_authorization: str, below_value_prices: list[Box]) -> Box:
    """Construct the headers for a token when sending a price below notification."""
    latest_below_value_price = max(below_value_prices, key=lambda price_point: price_point.start_timestamp)

    headers = Box()
    headers["authorization"] = f"bearer {apns_authorization}"
    headers["apns-collapse-id"] = defaults.NOTIFICATION.COLLAPSE_ID
    headers["apns-expiration"] = latest_below_value_price.start_timestamp
    headers["apns-priority"] = defaults.NOTIFICATION.PRIORITY
    headers["apns-push-type"] = defaults.NOTIFICATION.PUSH_TYPE
    headers["apns-topic"] = awattprice.defaults.APP_BUNDLE_ID

    return headers


def construct_notification(token: Token) -> Box:
    """Construct the notification for a token."""
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

    apns_authorization = await awattprice_notifications.apns.get_apns_authorization(config)

    for region, tokens in regions_tokens.items():
        if tokens is None:
            continue

        region_prices = price_data[region]

        for token in tokens:
            price_below = token.price_below

            below_value_prices = region_prices.get_prices_below_value(price_below.below_value, price_tax)

            headers = construct_notification_headers(apns_authorization, below_value_prices)
            notification = construct_notification(token)
