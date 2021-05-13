"""Contains default values and models."""
from enum import Enum


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

# Timeout in seconds when requesting from aWATTar.
AWATTAR_TIMEOUT = 10
# The aWATTar API refresh interval. After polling the API wait x seconds before requesting again.
AWATTAR_REFRESH_INTERVAL = 60
# Attempt to update aWATTar prices if its past this hour of the day.
# The backend autmatically switches between summer and winter times.
# So for example 13 o'clock will always stay 13 o'clock independent of summer or winter time.
AWATTAR_UPDATE_HOUR = 13
# Factor to convert seconds into microseconds.
TO_MICROSECONDS = 1000
# File name for file storing aWATTar price data.
# The string will be formatted with the lowercase region identifier.
PRICE_DATA_FILE_NAME = "awattar-data-{}.json"
# File name of lock file which will be acquired when aWATTar price data needs to be updated.
# The string will be formatted with the lowercase region identifier.
PRICE_DATA_UPDATE_LOCK = "awattar-data-{}-update.lck"
