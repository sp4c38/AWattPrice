"""Contains default values and models."""
from enum import Enum

DEFAULT_CONFIG = """\
[paths]
log_path = ~/awattprice/logs/
"""

class Region(str, Enum):
    """Identify a region (country)."""
    DE = "DE"
    AT = "AT"
