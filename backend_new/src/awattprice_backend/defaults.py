"""Contains default values and models."""
from enum import Enum

class Region(str, Enum):
    """Identify a region (country)."""
    DE = "DE"
    AT = "AT"
