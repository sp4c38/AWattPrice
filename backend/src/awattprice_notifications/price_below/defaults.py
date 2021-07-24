"""Default values and models for the price below notification service."""
from awattprice.defaults import Region
from box import Box

# Regions for which to send price below notifications.
REGIONS_TO_SEND = [Region.DE, Region.AT]

NOTIFICATION = Box(
    {
        "push_type": "alert",
        "priority": 5,
        "collapse_id": "price-below-notification",
        "title_loc_key": "general.priceGuard",
        "loc_keys": {
            "single_price": "notifications.price_drops_below.body.sing",
            "multiple_prices": "notifications.price_drops_below.body.mult",
        },
        "sound": "default",
    }
)
