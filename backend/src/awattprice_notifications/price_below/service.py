"""Send price below notifications to users.

See 'notifications.price_below.service.md' doc for description of this service.
"""
import asyncio

import awattprice_notifications

from awattprice import configurator
from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below import prices


async def main():
    """Run steps to send price below notifications to users."""
    config = configurator.get_config()
    configurator.configure_loguru(awattprice_notifications.defaults.PRICE_BELOW_SERVICE_NAME, config)

    regions_data = await prices.collect_multiple_region_prices(defaults.REGIONS_TO_SEND, config)
    print(regions_data)


if __name__ == "__main__":
    asyncio.run(main())
