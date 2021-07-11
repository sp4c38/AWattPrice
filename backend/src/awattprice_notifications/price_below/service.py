"""Send price below notifications to users.

See 'notifications.price_below.service.md' doc for description of this service.
"""
import asyncio
import sys

import awattprice

from loguru import logger

from awattprice_notifications import defaults as notifications_defaults
from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below import notifications
from awattprice_notifications.price_below import prices
from awattprice_notifications.price_below import tokens


async def main():
    """Run steps to send price below notifications to users."""
    config = awattprice.configurator.get_config()
    price_below_service_name = notifications_defaults.PRICE_BELOW_SERVICE_NAME
    awattprice.configurator.configure_loguru(price_below_service_name, config)

    try:
        database_engine = awattprice.database.get_engine(config, async_=True)
    except FileNotFoundError as exc:
        logger.exception(exc)
        sys.exit(1)

    regions_data = await prices.collect_regions_data(config, defaults.REGIONS_TO_SEND)

    # IMPLEMENT: Get the regions where price data updated relative to the last run.
    # regions_updated = select_regions_updated(regions_data, config)
    updated_regions = [awattprice.defaults.Region.DE]
    updated_regions_data = {region: regions_data[region] for region in updated_regions}

    for detailed_prices in updated_regions_data.values():
        detailed_prices.set_lowest_price()

    applying_tokens = await tokens.collect_applying_tokens(database_engine, updated_regions_data)

    await notifications.send_price_below_notifications(applying_tokens, updated_regions_data)


if __name__ == "__main__":
    asyncio.run(main())
