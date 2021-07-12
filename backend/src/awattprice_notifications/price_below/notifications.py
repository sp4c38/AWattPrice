"""Send price below notifications."""
from awattprice.defaults import Region
from awattprice.orm import Token
from box import Box
from liteconfig import Config

from awattprice_notifications.price_below.prices import DetailedPriceData


async def get_apns_request_info(config: Config) -> Box:
    """Get info needed to make requests to the apns."""
    pass



async def send_notifications(
    config: Config, tokens: dict[Region, list[Token]], price_data: dict[Region, DetailedPriceData]
):
    """Send price below notifications for certain tokens.

    :param tokens, price_data: Each region which has applying tokens *must* also be present in the price data.
    """
    request_data = get_apns_request_info(config)
    print(request_data)
