"""Send price below notifications."""
import awattprice

from awattprice.defaults import Region
from awattprice.orm import Token
from box import Box
from liteconfig import Config

import awattprice_notifications

from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below.prices import DetailedPriceData


def get_notification_headers(
    apns_authorization: str, below_value_prices: list[Box]
) -> Box:
    """Get headers needed to send a certain price below notification."""
    request_headers = Box()
    request_headers.authorization = f"bearer {apns_authorization}"
    request_headers["apns-collapse-id"] = defaults.NOTIFICATION.COLLAPSE_ID
    latest_below_value_price = max(below_value_prices, key=lambda price_point: price_point.start_timestamp)
    request_headers["apns-expiration"] = latest_below_value_price.start_timestamp
    request_headers["apns-priority"] = defaults.NOTIFICATION.PRIORITY
    request_headers["apns-push-type"] = defaults.NOTIFICATION.PUSH_TYPE
    request_headers["apns-topic"] = awattprice.defaults.APP_BUNDLE_ID

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

    apns_authorization = await awattprice_notifications.apns.get_apns_authorization(config)

    for region, tokens in regions_tokens.items():
        if tokens is None:
            continue

        region_prices = price_data[region]

        for token in tokens:
            price_below = token.price_below

            price_tax = None
            if token.tax is True:
                price_tax = region.tax
            below_value_prices = region_prices.get_prices_below_value(price_below.below_value, price_tax)

            headers = get_notification_headers(apns_authorization, below_value_prices)
            notification = construct_token_notification(token)
            print(headers)
            print(notification)
