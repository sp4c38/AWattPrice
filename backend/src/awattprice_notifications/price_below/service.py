"""Send price below notifications to users.
"""
import asyncio
import sys

from awattprice import configurator
from awattprice import notification_profiles
from loguru import logger

from awattprice_notifications import defaults as notification_defaults
from awattprice_notifications.price_below import notifications
from awattprice_notifications.price_below import prices
from box import Box


def collect_active_profiles(profile_store: notification_profiles.NotificationProfileStore) -> Box[str, list[Box]]:
    """Collect active notification profiles grouped by market area."""
    area_profiles = Box()
    for profile in profile_store.list_profiles():
        if not notifications.active_rule_types(profile):
            continue
        area_profiles.setdefault(profile.general.area, []).append(profile)
    return area_profiles


async def main():
    """Run steps to send price below notifications to users."""
    config = configurator.get_config()
    price_below_service_name = notification_defaults.PRICE_BELOW_SERVICE_NAME
    configurator.configure_loguru(price_below_service_name, config)

    profile_store = notification_profiles.NotificationProfileStore(notification_profiles.get_store_path(config))

    active_area_profiles = collect_active_profiles(profile_store)
    active_areas = list(active_area_profiles.keys())
    if len(active_areas) == 0:
        logger.debug("No active notification subscriptions.")
        sys.exit(0)

    areas_prices = await prices.collect_areas_prices(config, active_areas)
    if len(areas_prices) == 0:
        logger.warning("No current price data for all checked areas.")
        sys.exit(0)

    updated_areas = await prices.get_updated_areas(config, areas_prices)
    if not updated_areas:
        logger.debug("Aborting as there are currently no areas which updated relative to the last run.")
        sys.exit(0)

    notifiable_areas_prices = prices.get_notifiable_areas_prices(areas_prices)
    if len(notifiable_areas_prices) == 0:
        logger.debug("No notifiable prices for all checked areas.")
        sys.exit(0)
    for notifiable_prices in notifiable_areas_prices.values():
        notifiable_prices.find_lowest_price()

    updated_notifiable_areas_prices = {area_key: notifiable_areas_prices[area_key] for area_key in updated_areas}

    updated_active_area_profiles = Box(
        {
            area_key: active_area_profiles[area_key]
            for area_key in updated_notifiable_areas_prices.keys()
            if area_key in active_area_profiles
        }
    )

    await notifications.deliver_notifications(
        profile_store, config, updated_active_area_profiles, updated_notifiable_areas_prices
    )

    await prices.write_updated_areas_endtimes(config, areas_prices, updated_areas)


if __name__ == "__main__":
    asyncio.run(main())
