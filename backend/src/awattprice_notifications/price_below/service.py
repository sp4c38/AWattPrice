"""Send price below notifications to users.

See 'notifications.price_below.service.md' doc for description of this service.
"""
import asyncio
import sys

import awattprice

from loguru import logger

import awattprice_notifications

from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below import prices
from awattprice_notifications.price_below import tokens
from awattprice_notifications.price_below import utils


async def main():
    """Run steps to send price below notifications to users."""
    config = awattprice.configurator.get_config()
    price_below_service_name = awattprice_notifications.defaults.PRICE_BELOW_SERVICE_NAME
    awattprice.configurator.configure_loguru(price_below_service_name, config)

    regions_data = await prices.collect_regions_data(config, defaults.REGIONS_TO_SEND)
    # IMPLEMENT: Get the regions where price data updated relative to the last run.
    # regions_updated = get_regions_updated(regions_data, config)
    regions_updated = [
        awattprice.defaults.Region.DE
    ]  # Only includes regions which are also included in regions_data.

    try:
        database_engine = awattprice.database.get_engine(config, async_=True)
    except FileNotFoundError as exc:
        logger.exception(exc)
        sys.exit(1)
    legacy_database_engine = None
    if config.paths.legacy_database is not None:
        try:
            legacy_database_engine = utils.get_async_legacy_engine(config)
        except FileNotFoundError as exc:
            logger.exception(exc)
            sys.exit(1)

    # Tokens which apply to receive a price below notification.
    applying_tokens = await tokens.collect_applying_tokens()


if __name__ == "__main__":
    asyncio.run(main())
