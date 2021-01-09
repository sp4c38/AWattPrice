# -*- coding: utf-8 -*-

"""

AWattPrice default values

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

from enum import Enum
from loguru import logger as log
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

[notifications]
# If set to True the APNs sandbox server is used to send notifications.
use_sandbox: True
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


CONVERT_MWH_KWH = 100 * 0.001
TIME_CORRECT = 1000  # Correct milli seconds used by Awattar to seconds

class Price_Drops_Below:

    def __init__(self):
        # Use localization keys which are resolved on the client side
        self.title_loc_key = "general.priceGuard"
        self.body_loc_key = "notifications.price_drops_below.body"
        self.collapse_id = "collapse.priceDropsBelow3DK203W0#"


class Notifications:

    def set_values(self, config) -> bool:
        self.price_drops_below_notification = Price_Drops_Below()
        self.encryption_algorithm = "ES256"

        try:
            dev_team_id_path = Path(config.notifications.dev_team_id).expanduser()
            self.dev_team_id = (
                open(dev_team_id_path.as_posix(), "r").readlines()[0].replace("\n", "")
            )
            encryption_key_id_path = Path(
                config.notifications.apns_encryption_key_id
            ).expanduser()
            self.encryption_key_id = (
                open(encryption_key_id_path.as_posix(), "r")
                .readlines()[0]
                .replace("\n", "")
            )
            encryption_key_path = Path(
                config.notifications.apns_encryption_key
            ).expanduser()
            self.encryption_key = open(encryption_key_path.as_posix(), "r").read()
            self.url_path = "/3/device/{}"
        except Exception as e:
            log.warning(
                f"Couldn't read or find file(s) containing required information to send notifications "
                f"with APNs. Notifications won't be checked and won't be sent by the backend: {e}."
            )
            return False

        if config.notifications.use_sandbox:
            self.apns_server_url = "https://api.sandbox.push.apple.com"
            self.bundle_id = "me.space8.AWattPrice.dev"
        else:
            self.apns_server_url = "https://api.push.apple.com"
            self.bundle_id = "me.space8.AWattPrice"
        self.apns_server_port = 443

        return True
