# -*- coding: utf-8 -*-

"""

AWattPrice default values

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

from enum import Enum
from filelock import FileLock
from pathlib import Path

DEFAULT_CONFIG = """
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
apns_encryption_key = ~/awattprice/apns/encryption_key.p8

[poll]
# Try to update the data if there are less than this number of future energy price points.
# This uses the CET timezone to find how many future energy price points there are.
if_less_than: 12
# Do not poll the aWATTar API more frequent than this in seconds
awattar: 30
"""


class Region(Enum):
    """Country"""
    # Region names may not contain __
    DE = 0
    AT = 1


CONVERT_MWH_KWH = 100 * 0.001
TIME_CORRECT = 1000  # Correct milli seconds used by Awattar to seconds


class Notifications:
    class Price_Drops_Below:
        def __init__(self):
            self.title_loc_key = "notifications.price_drops_below.title"
            self.body_loc_key = "notifications.price_drops_below.body"

    def __init__(self, config):
        self.price_drops_below_notification = self.Price_Drops_Below()
        self.encryption_algorithm = "ES256"
        path = Path(config.file_location.apns_encryption_key).expanduser()
        lock_path = Path(f"{config.file_location.apns_encryption_key}.lck").expanduser()
        lock = FileLock(lock_path.as_posix())
        lock.acquire()
        self.encryption_key = open(path.as_posix(), "r").read()
        print(path.as_posix())
        lock.release()
        self.url_path = "/3/device/{}"

        self.bundle_id = "me.space8.AWattPrice.dev"
        self.apns_server = "api.sandbox.push.apple.com:443"
