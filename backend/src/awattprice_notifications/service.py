"""Run notification delivery for configured users."""
import asyncio
import time
import uuid

from awattprice import configurator
from awattprice import notification_profiles
from loguru import logger

from awattprice_notifications import apns
from awattprice_notifications import cronitor
from awattprice_notifications import payloads
from awattprice_notifications import prices
from box import Box


def collect_active_profiles(profile_store: notification_profiles.NotificationProfileStore) -> Box[str, list[Box]]:
    """Collect active notification profiles grouped by market area."""
    area_profiles = Box()
    for profile in profile_store.list_profiles():
        if not payloads.active_rule_types(profile):
            continue
        area_profiles.setdefault(profile.general.area, []).append(profile)
    return area_profiles


async def run_worker_cycle(config, profile_store: notification_profiles.NotificationProfileStore) -> dict:
    """Run one notification worker cycle and return monitoring metadata."""
    active_area_profiles = collect_active_profiles(profile_store)
    active_areas = list(active_area_profiles.keys())
    if len(active_areas) == 0:
        logger.debug("No active notification subscriptions.")
        return {"reason": "no_active_subscriptions", "active_area_count": 0, "updated_area_count": 0, "notification_count": 0, "error_count": 0}

    areas_prices = await prices.collect_areas_prices(config, active_areas)
    if len(areas_prices) == 0:
        logger.warning("No current price data for all checked areas.")
        return {"reason": "no_price_data", "active_area_count": len(active_areas), "updated_area_count": 0, "notification_count": 0, "error_count": 0}

    updated_areas = await prices.get_updated_areas(config, areas_prices)
    if not updated_areas:
        logger.debug("Aborting as there are currently no areas which updated relative to the last run.")
        return {"reason": "no_updated_areas", "active_area_count": len(active_areas), "updated_area_count": 0, "notification_count": 0, "error_count": 0}

    notifiable_areas_prices = prices.get_notifiable_areas_prices(areas_prices)
    if len(notifiable_areas_prices) == 0:
        logger.debug("No notifiable prices for all checked areas.")
        return {"reason": "no_notifiable_prices", "active_area_count": len(active_areas), "updated_area_count": len(updated_areas), "notification_count": 0, "error_count": 0}
    updated_notifiable_areas_prices = {
        area_key: notifiable_areas_prices[area_key]
        for area_key in updated_areas
        if area_key in notifiable_areas_prices
    }
    if len(updated_notifiable_areas_prices) == 0:
        logger.debug("No updated areas have complete notifiable prices.")
        return {"reason": "no_updated_notifiable_prices", "active_area_count": len(active_areas), "updated_area_count": len(updated_areas), "notification_count": 0, "error_count": 0}

    updated_active_area_profiles = Box(
        {
            area_key: active_area_profiles[area_key]
            for area_key in updated_notifiable_areas_prices.keys()
            if area_key in active_area_profiles
        }
    )

    notification_count, error_count = await payloads.deliver_notifications(
        profile_store, config, updated_active_area_profiles, updated_notifiable_areas_prices
    )

    await prices.write_updated_areas_endtimes(config, areas_prices, list(updated_notifiable_areas_prices.keys()))

    return {
        "reason": "delivered",
        "active_area_count": len(active_areas),
        "updated_area_count": len(updated_areas),
        "notification_count": notification_count,
        "error_count": error_count,
    }


def monitoring_message(result: dict) -> str:
    """Build a compact Cronitor message for one worker cycle."""
    return (
        f"reason={result['reason']}; "
        f"active_areas={result['active_area_count']}; "
        f"updated_areas={result['updated_area_count']}; "
        f"notifications={result['notification_count']}; "
        f"errors={result['error_count']}"
    )


async def main():
    """Run one notification worker cycle."""
    config = configurator.get_config()
    configurator.configure_loguru(apns.NOTIFICATIONS_SERVICE_NAME, config)
    cronitor.require_configured(config)

    series = str(uuid.uuid4())
    started_at = time.monotonic()
    await cronitor.send_event(config, "run", series, message="notification worker started")

    profile_store = notification_profiles.NotificationProfileStore(notification_profiles.get_store_path(config))

    try:
        result = await run_worker_cycle(config, profile_store)
    except Exception as exc:
        duration = time.monotonic() - started_at
        await cronitor.send_event(
            config,
            "fail",
            series,
            message=f"notification worker failed: {exc}",
            duration=duration,
            error_count=1,
            status_code=1,
        )
        raise

    duration = time.monotonic() - started_at
    await cronitor.send_event(
        config,
        "complete",
        series,
        message=monitoring_message(result),
        duration=duration,
        count=result["notification_count"],
        error_count=result["error_count"],
        status_code=0,
    )


if __name__ == "__main__":
    asyncio.run(main())
