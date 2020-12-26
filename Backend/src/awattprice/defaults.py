# -*- coding: utf-8 -*-

"""

AWattPrice default values

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

from enum import Enum

DEFAULT_CONFIG = """
[awattar.de]
host: https://api.awattar.de
url: /v1/marketdata

[awattar.at]
host: https://api.awattar.at
url: /v1/marketdata

[file_location]
data_dir:   ~/awattprice/data/
log_dir: ~/awattprice/log/
apns_dir: ~/awattprice/apns/

[poll]
# Try to update the data if there are less than this number of future energy price points.
# This uses the CET timezone to find how many future energy price points there are.
if_less_than: 12
# Do not poll the aWATTar API more frequent than this in seconds
awattar: 30
"""


class Region(Enum):
    """Country"""

    AT = 1
    DE = 2


CONVERT_MWH_KWH = 100 * 0.001
TIME_CORRECT = 1000  # Correct milli seconds used by Awattar to seconds
