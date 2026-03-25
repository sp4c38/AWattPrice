"""Default values and models for the price below notification service."""
from typing import Optional

import arrow

from arrow import Arrow
from awattprice import defaults as awattprice_defaults
from awattprice import prices as awattprice_prices
from box import Box
from loguru import logger

# Areas for which to send price below notifications.
MARKET_AREAS_TO_SEND = list(awattprice_defaults.SUPPORTED_MARKET_AREAS.keys())

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

    area = awattprice_defaults.get_market_area(price_data.area)
    now_local = arrow.now(area.timezone)
    tomorrow_start = now_local.floor("day").shift(days=+1)
    tomorrow_end = tomorrow_start.shift(days=+1)
    expected_points = int(
        (tomorrow_end - tomorrow_start).total_seconds() / awattprice_prices.resolution_to_seconds(price_data.resolution)
    )

    for price_point in price_data.prices:
        if (
            price_point.start_timestamp >= tomorrow_start
            and price_point.end_timestamp <= tomorrow_end
        ):
            selected_prices.append(price_point)

    if len(selected_prices) != expected_points:
        logger.debug(f"Length of selected prices isn't equal to {expected_points}: {len(selected_prices)}.")
        return None

    return selected_prices


def check_area_updated(stored_endtime: Optional[Arrow], new_endtime: Arrow, area_key: str) -> bool:
    """Check if an area can be marked as updated relative to previous runs based on the endtimes."""
    area = awattprice_defaults.get_market_area(area_key)
    now = arrow.now().to(area.timezone)
    tomorrow_midnight = now.floor("day").shift(days=+2)
    if not new_endtime == tomorrow_midnight:
        return False

    if stored_endtime is None:
        # It's important to run this after it was confirmed that the new endtime is at tomorrows midnight.
        return True

    timedelta = new_endtime - stored_endtime
    if not timedelta.total_seconds() >= 86400:  # Equals one day
        return False

    return True
