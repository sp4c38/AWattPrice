"""Default values and models for the notification worker."""
from typing import Optional

import arrow

from arrow import Arrow
from awattprice import defaults as awattprice_defaults
from awattprice import prices as awattprice_prices
from box import Box
from loguru import logger

NOTIFICATION_LAST_UPDATED_ENDTIME_FILE_NAME = "notification-last-updated-{}-endtime.pickle"
NOTIFICATION_PRICE_UPDATE_FRESH_SECONDS = 3 * 60 * 60
NOTIFICATION_MAX_FALLBACK_SECONDS = 2 * 60 * 60

NOTIFICATION = Box(
    {
        "push_type": "alert",
        "priority": 5,
        "collapse_ids": {
            "price_below": "awattprice_notifications_price_below",
            "price_above": "awattprice_notifications_price_above",
            "daily_summary": "awattprice_notifications_daily_summary",
        },
        "title_loc_keys": {
            "price_below": "notifications.price_below.title",
            "price_above": "notifications.price_above.title",
            "daily_summary": "notifications.daily_summary.title",
        },
        "loc_keys": {
            "price_below_single": "notifications.price_below.body.single",
            "price_below_multiple": "notifications.price_below.body.multiple",
            "price_below_single_15min": "notifications.price_below.body.single.15min",
            "price_below_multiple_15min": "notifications.price_below.body.multiple.15min",
            "price_above_single": "notifications.price_above.body.single",
            "price_above_multiple": "notifications.price_above.body.multiple",
            "price_above_single_15min": "notifications.price_above.body.single.15min",
            "price_above_multiple_15min": "notifications.price_above.body.multiple.15min",
            "daily_summary": "notifications.daily_summary.body",
        },
        "example_loc_keys": {
            "price_below": "notifications.price_below.body.example",
            "price_above": "notifications.price_above.body.example",
            "daily_summary": "notifications.daily_summary.body.example",
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

    if not check_notifiable_price_quality(selected_prices, price_data.resolution):
        return None

    return selected_prices


def check_notifiable_price_quality(selected_prices: list[Box], resolution: str) -> bool:
    """Return true when fallback prices stay within the notification tolerance."""
    interval_seconds = awattprice_prices.resolution_to_seconds(resolution)
    fallback_count = sum(1 for price_point in selected_prices if price_point.get("is_fallback", False))
    fallback_seconds = fallback_count * interval_seconds
    if fallback_seconds > NOTIFICATION_MAX_FALLBACK_SECONDS:
        logger.debug(
            f"Too many fallback prices for notification delivery: "
            f"{fallback_seconds} seconds exceeds {NOTIFICATION_MAX_FALLBACK_SECONDS} seconds."
        )
        return False

    return True


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


def check_price_update_fresh(last_update_time: Optional[Arrow], area_key: str, now=None) -> bool:
    """Return true when the cached prices were refreshed recently enough to notify."""
    if last_update_time is None:
        return False

    area = awattprice_defaults.get_market_area(area_key)
    current = (now or arrow.now()).to(area.timezone)
    update_time = last_update_time.to(area.timezone)
    age_seconds = (current - update_time).total_seconds()
    return 0 <= age_seconds <= NOTIFICATION_PRICE_UPDATE_FRESH_SECONDS
