"""Contains default values and models."""
from enum import auto
from enum import Enum

from box import Box

from awattprice import defaults


class Region(str, Enum):
    """Identify a region (country)."""

    DE = "DE"
    AT = "AT"


DEFAULT_CONFIG = """\
[general]
debug = off

[awattar.de]
url = https://api.awattar.de/v1/marketdata/

[awattar.at]
url = https://api.awattar.at/v1/marketdata/

[paths]
log_dir = ~/awattprice/logs/
data_dir = ~/awattprice/data/
"""

ORM_TABLE_NAMES = Box(
    {
        "token_table": "token",
        "price_below_table": "price_below_notification",
    }
)

# Factor to convert seconds into microseconds.
TO_MICROSECONDS = 1000

# Timeout in seconds when requesting from aWATTar.
AWATTAR_TIMEOUT = 10.0
# The aWATTar API refresh interval. After polling the API wait x seconds before requesting again.
AWATTAR_REFRESH_INTERVAL = 60
# Attempt to update aWATTar prices if its past this hour of the day.
# The backend autmatically switches between summer and winter times.
# So for example 13 o'clock will always stay 13 o'clock independent of summer or winter time.
AWATTAR_UPDATE_HOUR = 13

# File name for the AWattPrice backend database ending.
DATABASE_FILE_NAME = "database.sqlite3"  # End with '.sqlite3'

# File name for file storing aWATTar price data.
# The string will be formatted with the lowercase region identifier.
PRICE_DATA_FILE_NAME = "awattar-data-{}.json"
# Name of the subdir in which to store cached price data.
# This subdir is relative to the data dir specified in the config file.
PRICE_DATA_SUBDIR_NAME = "price_data"
# File name of lock file which will be acquired when aWATTar price data needs to be updated.
# The string will be formatted with the lowercase region identifier.
PRICE_DATA_REFRESH_LOCK = "awattar-data-{}-update.lck"
# Timeout in seconds to wait when needing the refresh price data lock to be unlocked.
PRICE_DATA_REFRESH_LOCK_TIMEOUT = AWATTAR_TIMEOUT + 2.0

# Describes structure of the json body when the client sends tasks to update its notification settings.
class TaskType(Enum):
    """Different types of tasks which can be sent by the client to change their notification config."""

    add_token = auto()
    subscribe_desubscribe = auto()
    update = auto()


class NotificationType(Enum):
    """Different notification types."""

    price_below = auto()


class UpdateSubject(Enum):
    """Subjects on which updates can be performed.

    Its the best to use a explicit approach as oppossed to using a general way when updating values.
    Each subject has a own schema and function which knows how to apply updates on it. There is no and
    should be no "general way" of updating values the same way on each subject.
    """
    general = auto()
    price_below = auto()


NOTIFICATION_TASKS_BODY_SCHEMA = {
    "type": "object",
    "properties": {
        "token": {"type": "string", "minLength": 1},
        "tasks": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "type": {"enum": [element.name for element in TaskType]},
                    "payload": {"type": "object"},
                },
                "required": ["type", "payload"],
                "additionalProperties": False,
            },
            "minItems": 1,
        },
    },
    "required": ["token", "tasks"],
    "additionalProperties": False,
}

region_enum_names = [element.name for element in defaults.Region]

NOTIFICATION_TASK_ADD_TOKEN_SCHEMA = {
    "type": "object",
    "properties": {"region": {"enum": region_enum_names}, "tax": {"type": "boolean"}},
    "required": ["region", "tax"],
    "additionalProperties": False,
}

NOTIFICATION_TASK_SUB_DESUB_SCHEMA = {
    "type": "object",
    "properties": {
        "notification_type": {"enum": [element.name for element in NotificationType]},
        "sub_else_desub": {"type": "boolean"},
        "notification_info": {"type": "object"},
    },
    "required": ["sub_else_desub", "notification_type", "notification_info"],
    "additionalProperties": False,
}

NOTIFICATION_TASK_PRICE_BELOW_SUB_DESUB_SCHEMA = {
    "type": "object",
    "properties": {"below_value": {"type": "number"}},
    "required": ["below_value"],
    "additionalProperties": False,
}

NOTIFICATION_TASK_UPDATE_SCHEMA = {
    "type": "object",
    "properties": {
        "subject": {"enum": [element.name for element in UpdateSubject]},
        "updated_data": {"type": "object"},
    },
    "required": ["subject", "updated_data"],
    "additionalProperties": False,
}

NOTIFICATION_TASK_UPDATE_GENERAL_SCHEMA = {
    "type": "object",
    "properties": {
        # Don't reuse same previouse properties from add token because they might need to change without the
        # updater functions beeing capable of updating such new/updated values.
        "region": {"enum": region_enum_names},
        "tax": {"type": "boolean"},
    },
    "minProperties": 1,
    "additionalProperties": False,
}

NOTIFICATION_TASK_UPDATE_PRICE_BELOW_SCHEMA = {
    "type": "object", 
    "properties": {
        "below_value": {"type": "number"}
    },
    "minProperties": 1,
    "additionalProperties": False,
}
