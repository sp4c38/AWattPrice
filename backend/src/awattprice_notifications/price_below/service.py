"""Send price below notifications to users.
"""
import asyncio
import sys

from awattprice import configurator
from awattprice import database
from loguru import logger

from awattprice_notifications import defaults as notification_defaults
from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below import notifications
from awattprice_notifications.price_below import prices
from awattprice_notifications.price_below import tokens


async def main():
    """Run steps to send price below notifications to users."""
    config = configurator.get_config()
    price_below_service_name = notification_defaults.PRICE_BELOW_SERVICE_NAME
    configurator.configure_loguru(price_below_service_name, config)

    try:
        engine = database.get_awattprice_engine(config, async_=True)
    except FileNotFoundError as exc:
        logger.exception(exc)
        sys.exit(1)

    active_areas = await tokens.collect_active_areas(engine)
    if len(active_areas) == 0:
        logger.debug("No active Price Guard subscriptions.")
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

    applying_areas_tokens = await tokens.collect_applying_tokens(engine, updated_notifiable_areas_prices)

    await notifications.deliver_notifications(
        engine, config, applying_areas_tokens, updated_notifiable_areas_prices
    )

    await prices.write_updated_areas_endtimes(config, areas_prices, updated_areas)


if __name__ == "__main__":
    asyncio.run(main())
