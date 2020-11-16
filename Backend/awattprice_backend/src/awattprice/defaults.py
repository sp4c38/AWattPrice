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

[file_location]
data_dir:   ~/awattprice/data/
log_dir: ~/awattprice/log/

[poll]
# Do not poll more frequent than this in seconds
awattar: 300
"""


class Region(Enum):
    """Country"""

    AT = 1
    DE = 2


CONVERT_MWH_KWH = 100 * 0.001
TIME_CORRECT = 1000  # Correct milli seconds used by Awattar to seconds
