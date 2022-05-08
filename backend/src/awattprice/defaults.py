"""Contains default values and models."""
from decimal import Decimal
from enum import auto
from enum import Enum
from typing import Optional

from box import Box


class Region(str, Enum):
    """Identify a region (country)."""

    DE = "DE"
    AT = "AT"

    @property
    def tax(self) -> Optional[Decimal]:
        tax = REGION_TAXES[self]
        return tax


# Multipliers to get the taxed price.
REGION_TAXES = {Region.DE: Decimal("1.19"), Region.AT: Decimal("1.20")}

AWATTPRICE_SERVICE_NAME = "awattprice"
APP_BUNDLE_ID = Box()
APP_BUNDLE_ID.production = "me.space8.AWattPrice"
APP_BUNDLE_ID.staging = "me.space8.AWattPrice.staging"

DEFAULT_CONFIG = """\
[general]
staging = true
# Log level name (Severity): TRACE (5), DEBUG (10), INFO (20), SUCCESS (25), WARNING (30), ERROR (40), CRITICAL (50)
log_level = DEBUG

[awattar.de]
url = https://api.awattar.de/v1/marketdata/

[awattar.at]
url = https://api.awattar.at/v1/marketdata/

[paths]
log_dir = ~/awattprice/logs/
data_dir = ~/awattprice/data/
apns_dir = ~/awattprice/apns/
old_database =

[apns]
team_id = 
key_id = 
"""

ORM_TABLE_NAMES = Box(
    {
        "token_table": "token",
        "price_below_table": "price_below_notification",
    }
)

# Factors to convert between sizes.
SEC_TO_MILLISEC = 1000
EURMWH_TO_CENTWKWH = Decimal("100") * Decimal("0.001")

# Number of places to round a cent per kwh price.
CENT_KWH_ROUNDING_PLACES = 2

AWATTAR_TIMEOUT = 7 # Timeout in seconds when requesting from aWATTar.
AWATTAR_RETRY_MAX_ATTEMPTS = 4
AWATTAR_RETRY_STOP_DELAY = 7 # Delay after which to stop retrying.
# After polling the API wait x seconds before requesting again. When a download attempt failed it won't count
# and following attempts won't need to wait for this cooldown.
AWATTAR_COOLDOWN_INTERVAL = 60
# Attempt to update aWATTar prices if its past this hour of the day.
# Always will update at x hour regardless of summer and winter times.
AWATTAR_UPDATE_HOUR = 13

EUROPE_BERLIN_TIMEZONE = "Europe/Berlin"

DATABASE_FILE_NAME = "database.sqlite3"  # End with '.sqlite3'


AWATTAR_API_PRICE_DATA_SCHEMA = {
    "type": "object",
    "properties": {
        "object": {"type": "string", "pattern": "^list$"},
        "data": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "start_timestamp": {"type": "integer"},
                    "end_timestamp": {"type": "integer"},
                    "marketprice": {"type": "number"},
                    "unit": {"type": "string", "pattern": "^Eur/MWh$"},
                },
                "required": ["start_timestamp", "end_timestamp", "marketprice", "unit"],
                "minItems": 1,
            },
        },
        "url": {"type": "string", "pattern": "^/at/v1/marketdata/|/de/v1/marketdata/$"},
    },
    "required": ["data", "url"],
}
PRICE_DATA_FILE_NAME = "awattar-data-{}.pickle"  # formatted with lowercase region name
# Name of the subdir in which to store cached price data.
# This subdir is relative to the data dir specified in the config file.
PRICE_DATA_SUBDIR_NAME = "price_data"
# Timeout in seconds to wait when needing the refresh price data lock to be unlocked.
PRICE_DATA_REFRESH_LOCK_TIMEOUT = 10
# Name of file which stores the timestamp when prices were updated last.
PRICE_DATA_UPDATE_TS_FILE_NAME = "update-ts-{}.info"  # formatted with lowercase region name

region_enum_names = [element.name for element in Region]

NOTIFICATION_CONFIGURATION_SCHEMA = {
    "type": "object",
    "properties": {
        "token": {"type": "string", "minLength": 1},

        "general": {
            "type": "object",
            "properties": {
                "region": {"enum": region_enum_names},
                "tax": {"type": "boolean"}
            },
            "required": ["region", "tax"],
            "additionalProperties": False
        },

        "notifications": {
            "type": "object",
            "properties": {
                "price_below": {
                    "type": "object",
                    "properties": {
                        "active": {"type": "boolean"},
                        "below_value": {"type": "number"}
                    },
                    "required": ["active", "below_value"],
                    "additionalProperties": False
                }
            },
            "required": ["price_below"],
            "additionalProperties": False
        }
    },
    "required": ["token", "general", "notifications"],
    "additionalProperties": False
}
