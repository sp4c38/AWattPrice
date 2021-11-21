# -*- coding: utf-8 -*-

"""

AWattPrice default values

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

from enum import Enum

DEFAULT_CONFIG = """
[general]
# Also if set to no debug logs will be outputted. If set to yes the Backend will enable/disable certain
# code blocks to make debugging easier.
debug_mode: no

[awattar.de]
host: https://api.awattar.de
url: /v1/marketdata

[awattar.at]
host: https://api.awattar.at
url: /v1/marketdata

[file_location]
data_dir: ~/awattprice/data/
log_dir: ~/awattprice/log/
apns_dir: ~/awattprice/apns/

[notifications]
# If set to yes the APNs sandbox server is used to send notifications.
use_sandbox: yes
dev_team_id: ~/awattprice/apns/dev_team_id.txt
apns_encryption_key_id: ~/awattprice/apns/encryption_key_id.txt
apns_encryption_key: ~/awattprice/apns/encryption_key.p8

[poll]
# Try to update the data if there are less than this number of future energy price points.
# This uses the CET timezone to find how many future energy price points there are.
if_less_than: 12

# Do not poll the aWATTar API more frequent than this in seconds
awattar: 30

# Optionally set the url (scheme with domain name and port) by which the Backend is accessible.
# This is used for scheduled requests to know where to access the Backend.
# Leave blank if scheduled requests aren't needed.
backend_url:
"""


class Region(Enum):
    """Country"""

    # Region names may not contain __
    DE = 0
    AT = 1


CURRENT_VAT = 1.19

CONVERT_MWH_KWH = 100 * 0.001
TIME_CORRECT = 1000  # Correct milli seconds used by aWATTar to seconds
