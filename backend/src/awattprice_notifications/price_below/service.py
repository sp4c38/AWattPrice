"""Send price below notifications to users.

See 'notifications.price_below.service.md' doc for description of this service. 
"""
from loguru import logger

from awattprice import configurator
from awattprice_notifications import defaults


def main():
    config = configurator.get_config()
    configurator.configure_loguru(defaults.PRICE_BELOW_SERVICE_NAME, config)



if __name__ == "__main__":
    main()
