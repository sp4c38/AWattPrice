"""Contains default values and models."""
from decimal import Decimal

from box import Box

from awattprice.market_areas import DEFAULT_MARKET_AREA_KEY
from awattprice.market_areas import MarketArea
from awattprice.market_areas import SUPPORTED_MARKET_AREAS
from awattprice.market_areas import get_market_area
from awattprice.market_areas import list_market_areas
from awattprice.market_areas import normalize_market_area_key

AWATTPRICE_SERVICE_NAME = "awattprice"
APP_BUNDLE_ID = Box()
APP_BUNDLE_ID.production = "me.space8.AWattPrice"

DEFAULT_CONFIG = """\
[general]
# Log level name (Severity): TRACE (5), DEBUG (10), INFO (20), SUCCESS (25), WARNING (30), ERROR (40), CRITICAL (50)
log_level = DEBUG

[entsoe]
url = https://web-api.tp.entsoe.eu/api
# When running in Docker, use the container path mounted by compose.v3.yaml.
# Do not use the host path such as /etc/awattprice-v3/entsoe-token.txt here.
token_file = ~/awattprice/entsoe-token.txt

[paths]
# When running in Docker, use the container paths mounted by compose.v3.yaml:
# /etc/awattprice/data, /etc/awattprice/logs, and /etc/awattprice/encryption_key.p8.
log_dir = ~/awattprice/logs/
data_dir = ~/awattprice/data/

[apns]
team_id = 
key_id = 
key_file = ~/awattprice/encryption_key.p8
"""

ORM_TABLE_NAMES = Box(
    {
        "token_table": "token",
        "price_below_table": "price_below_notification",
    }
)

DATABASE_FILE_NAME = "database.sqlite3"  # End with '.sqlite3'

PRICE_SUBUNIT_ROUNDING_PLACES = 2

ENTSOE_TIMEOUT = 40
ENTSOE_RETRY_MAX_ATTEMPTS = 4
ENTSOE_RETRY_STOP_DELAY = 40
ENTSOE_COOLDOWN_INTERVAL = 60
ENTSOE_UPDATE_HOUR = 13

PRICE_DATA_FILE_NAME = "price-data-{}.pickle"
PRICE_DATA_SUBDIR_NAME = "price_data"
PRICE_DATA_REFRESH_LOCK_TIMEOUT = 75
PRICE_DATA_UPDATE_TS_FILE_NAME = "update-ts-{}.info"

supported_market_area_keys = list(SUPPORTED_MARKET_AREAS.keys())

NOTIFICATION_CONFIGURATION_SCHEMA = {
    "type": "object",
    "properties": {
        "token": {"type": "string", "minLength": 1},

        "general": {
            "type": "object",
            "properties": {
                "area": {"enum": supported_market_area_keys},
                "tax": {"type": "boolean"},
                "base_fee": {"type": "number"},
                "percentage_add_on": {"type": "number"}
            },
            "required": ["area", "tax"],
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

NOTIFICATION_PROFILE_SCHEMA = {
    "type": "object",
    "properties": {
        "token": {"type": "string", "minLength": 1},
        "general": {
            "type": "object",
            "properties": {
                "area": {"enum": supported_market_area_keys},
                "tax": {"type": "boolean"},
                "base_fee": {"type": "number"},
                "percentage_add_on": {"type": "number"},
            },
            "required": ["area", "tax", "base_fee", "percentage_add_on"],
            "additionalProperties": False,
        },
        "rules": {
            "type": "object",
            "properties": {
                "price_below": {
                    "type": "object",
                    "properties": {
                        "active": {"type": "boolean"},
                        "threshold": {"type": ["number", "null"]},
                    },
                    "required": ["active"],
                    "additionalProperties": False,
                },
                "price_above": {
                    "type": "object",
                    "properties": {
                        "active": {"type": "boolean"},
                        "threshold": {"type": ["number", "null"]},
                    },
                    "required": ["active"],
                    "additionalProperties": False,
                },
                "daily_summary": {
                    "type": "object",
                    "properties": {
                        "active": {"type": "boolean"},
                    },
                    "required": ["active"],
                    "additionalProperties": False,
                },
            },
            "required": ["price_below", "price_above", "daily_summary"],
            "additionalProperties": False,
        },
    },
    "required": ["token", "general", "rules"],
    "additionalProperties": False,
}
