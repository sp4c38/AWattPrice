"""Default values and models for the price below notification service."""
from awattprice.defaults import Region
from box import Box

# Regions for which to send price below notifications.
REGIONS_TO_SEND = [Region.DE, Region.AT]

NOTIFICATION = Box(
    {
        "PUSH_TYPE": "alert",
        "PRIORITY": 5,
        "COLLAPSE_ID": "price-below-notification",
        "TITLE_LOC_KEY": "general.priceGuard",
        "LOC_KEY": "notifications.price_drops_below.body.sing",
        "SOUND": "default",
    }
)
