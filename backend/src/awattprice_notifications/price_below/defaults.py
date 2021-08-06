"""Default values and models for the price below notification service."""
import arrow
import awattprice

from arrow import Arrow
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


def get_notifiable_prices(price_data: Box) -> Optional[list[Box]]:
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

    if not len(selected_prices) == 24:
        return None

    return selected_prices


def check_region_updated(stored_endtime: Arrow, new_endtime: Arrow) -> bool:
    """Check if a region can be marked as updated to previouse runs based on the endtimes."""
    berlin_now = arrow.now().to(awattprice.defaults.EUROPE_BERLIN_TIMEZONE)
    berlin_tomorrow_midnight = berlin_now.shift(days=+2).ceil("day")
    new_endtime_berlin = new_endtime.to(awattprice.defaults.EUROPE_BERLIN_TIMEZONE)
    if not new_endtime_berlin == berlin_tomorrow_midnight:
        return False

    timedelta = new_endtime - stored_endtime
    if not timedelta.total_seconds() >= 86400:  # Equals one day
        return False

    return True