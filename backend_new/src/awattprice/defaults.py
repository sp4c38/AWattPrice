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

# Factor to convert seconds into microseconds.
TO_MICROSECONDS = 1000
# Timeout in seconds when requesting from aWATTar.
AWATTAR_TIMEOUT = 10
# File name for file storing aWATTar price data. 
# The string will be formatted with the lowercase region identifier.
PRICE_DATA_FILE_NAME = "awattar-data-{}.json"
