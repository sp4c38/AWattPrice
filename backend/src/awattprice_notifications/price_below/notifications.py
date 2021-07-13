"""Send price below notifications."""
from awattprice.defaults import Region
from awattprice.orm import Token
from liteconfig import Config

import awattprice_notifications

from awattprice_notifications.price_below.prices import DetailedPriceData


async def send_notifications(
    config: Config, tokens: dict[Region, list[Token]], price_data: dict[Region, DetailedPriceData]
):
    """Send price below notifications for certain tokens.

    :param tokens, price_data: Each region which has applying tokens *must* also be present in the price data.
    """
    apns_authorization = await awattprice_notifications.apns.get_apns_request_authorization(config)
    print(apns_authorization)
