"""Send price below notifications to users.

See 'notifications.price_below.service.md' doc for description of this service.
"""
import asyncio
import sys

from awattprice import configurator
from awattprice import database
from awattprice.defaults import Region
from loguru import logger

import awattprice_notifications

from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below import notifications
from awattprice_notifications.price_below import prices
from awattprice_notifications.price_below import tokens


async def main():
    """Run steps to send price below notifications to users."""
    config = configurator.get_config()
    price_below_service_name = awattprice_notifications.defaults.PRICE_BELOW_SERVICE_NAME
    configurator.configure_loguru(price_below_service_name, config)

    try:
        engine = database.get_awattprice_engine(config, async_=True)
    except FileNotFoundError as exc:
        logger.exception(exc)
        sys.exit(1)

    regions_prices = await prices.collect_regions_prices(config, defaults.REGIONS_TO_SEND)
    if len(regions_prices) == 0:
        logger.warning("No current price data for all checked regions.")
        sys.exit(0)

    updated_regions = await prices.get_updated_regions(config, regions_prices)
    if not updated_regions:
        logger.debug("Aborting as there are currently no regions which updated relative to the last run.")
        sys.exit(0)

    notifiable_regions_prices = prices.get_notifiable_regions_prices(regions_prices)
    if len(notifiable_regions_prices) == 0:
        logger.debug("No notifiable prices for all checked regions.")
        sys.exit(0)
    for notifiable_prices in notifiable_regions_prices.values():
        notifiable_prices.find_lowest_price()

    updated_notifiable_regions_prices = {region: notifiable_regions_prices[region] for region in updated_regions}

    applying_regions_tokens = await tokens.collect_applying_tokens(engine, updated_notifiable_regions_prices)

    await notifications.deliver_notifications(
        engine, config, applying_regions_tokens, updated_notifiable_regions_prices
    )

    await prices.write_updated_regions_endtimes(config, regions_prices, updated_regions)


if __name__ == "__main__":
    asyncio.run(main())
