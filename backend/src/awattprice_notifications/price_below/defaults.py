"""Default values and models for the price below notification service."""
from awattprice.defaults import Region

# Regions for which to send price below notifications.
REGIONS_TO_SEND = [Region.DE, Region.AT]

PRICE_BELOW_PUSH_TYPE = "alert"
PRICE_BELOW_PRIORITY = 5
PRICE_BELOW_COLLAPSE_ID = "price-below-notification"
