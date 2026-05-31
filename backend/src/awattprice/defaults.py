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

DEFAULT_ENTSOE_TOKEN_FILE = "/etc/awattprice/entsoe-token.txt"
DEFAULT_LOG_DIR = "/etc/awattprice/logs/"
DEFAULT_DATA_DIR = "/etc/awattprice/data/"
DEFAULT_APNS_KEY_FILE = "/etc/awattprice/encryption_key.p8"

DEFAULT_CONFIG = """\
[general]
# Log level name (Severity): TRACE (5), DEBUG (10), INFO (20), SUCCESS (25), WARNING (30), ERROR (40), CRITICAL (50)
log_level = DEBUG

[entsoe]
url = https://web-api.tp.entsoe.eu/api

[apns]
team_id = 
key_id = 

[cronitor]
api_key =
monitor_key =
refresher_monitor_key =
environment = production
"""

PRICE_SUBUNIT_ROUNDING_PLACES = 2

ENTSOE_TIMEOUT = 40
ENTSOE_RETRY_MAX_ATTEMPTS = 4
ENTSOE_RETRY_STOP_DELAY = 40
ENTSOE_COOLDOWN_INTERVAL = 60
ENTSOE_GENERATION_COOLDOWN_INTERVAL = 15 * 60
ENTSOE_UPDATE_HOUR = 13
REFRESHER_TIMEZONE = "Europe/Berlin"
REFRESHER_FAST_POLL_START_HOUR = 13
REFRESHER_FAST_POLL_END_HOUR = 16
REFRESHER_FAST_POLL_INTERVAL_SECONDS = 10 * 60
REFRESHER_SLOW_POLL_INTERVAL_SECONDS = 60 * 60
REFRESHER_GENERATION_INTERVAL_SECONDS = 20 * 60
REFRESHER_HISTORY_INTERVAL_SECONDS = 24 * 60 * 60
REFRESHER_CONCURRENCY = 3
REFRESHER_GENERATION_CONCURRENCY = 1
PRICE_HISTORY_RETENTION_DAYS = 5
GENERATION_RETENTION_HOURS = 168
GENERATION_RETENTION_SAFETY_HOURS = 6
CACHE_INDEX_FILE_NAME = "cache-index.sqlite"
REFRESHER_STATE_FILE_NAME = "refresher-state.json"

PRICE_DATA_FILE_NAME = "price-data-{}.pickle"
PRICE_DATA_SUBDIR_NAME = "price_data"
PRICE_HISTORY_DATA_SUBDIR_NAME = "history"
GENERATION_HISTORY_RESPONSE_FILE_NAME = "generation-history-{}-{}h.json"
GENERATION_METADATA_FILE_NAME = "generation-meta-{}.json"
GENERATION_REFRESH_LOCK_FILE_NAME = "generation-refresh-{}.lock"
GENERATION_DATA_SUBDIR_NAME = "generation_data"
PRICE_DATA_REFRESH_LOCK_TIMEOUT = 75
PRICE_DATA_UPDATE_TS_FILE_NAME = "update-ts-{}.info"

supported_market_area_keys = list(SUPPORTED_MARKET_AREAS.keys())

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
                "fixed_add_on": {"type": "number"},
                "monthly_fixed_cost_add_on": {"type": "number"},
                "add_on_order": {
                    "type": "array",
                    "items": {"enum": ["fixed", "percentage", "monthly"]},
                    "uniqueItems": True,
                },
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
