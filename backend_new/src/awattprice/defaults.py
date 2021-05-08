"""Contains default values and models."""
from enum import Enum


class Region(str, Enum):
    """Identify a region (country)."""

    DE = "DE"
    AT = "AT"


DEFAULT_CONFIG = """\
[general]
debug = on

[web]
awattar_de = "https://api.awattar.de/v1/marketdata/"
awattar_at = "https://api.awattar.at/v1/marketdata/"

[paths]
log = ~/awattprice/logs/
"""

# Factor to convert seconds into microseconds.
TO_MICROSECONDS = 1000
# Timeout in seconds when requesting from aWATTar.
AWATTAR_TIMEOUT = 10
