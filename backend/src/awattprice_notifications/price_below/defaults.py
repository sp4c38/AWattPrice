"""Default values and models for the price below notification service."""
import arrow
import awattprice

from awattprice.defaults import Region
from box import Box

# Regions for which to send price below notifications.
REGIONS_TO_SEND = [Region.DE, Region.AT]

LAST_UPDATED_ENDTIME_FILE_NAME = "last-updated-{}-endtime.pickle"

NOTIFICATION = Box(
    {
        "push_type": "alert",
        "priority": 5,
        "collapse_id": "price-below-notification",
        "title_loc_key": "general.priceGuard",
        "loc_keys": {
            "single_price": "notifications.price_drops_below.body.sing",
            "multiple_prices": "notifications.price_drops_below.body.mult",
        },
        "sound": "default",
    }
)


def get_notifiable_prices(price_data: Box) -> Box:
    """Get the prices about which users should be notified."""
    selected_prices = []

    now_berlin = arrow.now(awattprice.defaults.EUROPE_BERLIN_TIMEZONE)
    # Note: Time range must not exceed 24 hours.
    berlin_tomorrow_start = now_berlin.shift(days=+1).floor("day")
    berlin_tomorrow_end = berlin_tomorrow_start.shift(days=+1)

    for price_point in price_data:
        if (
            price_point.start_timestamp >= berlin_tomorrow_start
            and price_point.end_timestamp <= berlin_tomorrow_end
        ):
            selected_prices.append(price_point)

    return selected_prices
