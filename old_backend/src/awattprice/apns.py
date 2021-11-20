# -*- coding: utf-8 -*-

"""

Code to handle notification configuration from clients used for communication with APNs later.

"""
__author__ = "Léon Becker <lb@space8.me>"
__copyright__ = "Léon Becker"
__license__ = "mit"

import json

from typing import Optional

from loguru import logger as log

from awattprice.token_manager import APNsTokenManager
from awattprice.types import APNSToken


async def write_token(request_data: APNSToken):
    """Store APNs token configuration to the database."""
    log.info("Initiated a new background task to store an APNs configuration.")
    apns_token_manager = APNsTokenManager(request_data)

    apns_token_manager.set_data()


def validate_token(raw_data: bytes) -> Optional[APNSToken]:
    """Checks if the backend can successfully read and decode the APNs token configuration
    sent from a client.

    Clarification:
    When refering to APNs token configuration or APNs configuration or token configuration
    the token and all config data (like selected region in app, selected notifications to receive, ...)
    is meant.

    Example data:

    {"apnsDeviceToken": "ALovelyApnsToken", "regionIdentifier": 0, "vatSelection": 1,
    "notificationConfig": {"priceBelowValueNotification": {"active": true, "belowValue": 20}}}
    """

    try:
        data = json.loads(raw_data.decode("utf-8"))
    except json.JSONDecodeError as e:
        log.warning(f"Could not JSON encode the request: {e}")
        return None

    mappings = [
        ("apnsDeviceToken", "token"),
        ("regionIdentifier", "region_identifier"),
        ("vatSelection", "vat_selection"),
    ]

    request_data = {}
    for mapping in mappings:
        if mapping[0] not in data:
            log.warning(f"Key {mapping[0]} was not found in request data.")
            return None
        request_data[mapping[1]] = data[mapping[0]]

    if "notificationConfig" not in data:
        log.warning("Key notificationConfig not found in request data.")
        return None

    if "priceBelowValueNotification" not in data["notificationConfig"]:
        log.warning("Key notificationConfig.priceBelowValueNotification not found in request data.")
        return None
    notification_config = data["notificationConfig"]["priceBelowValueNotification"]
    notification_config_mapping = {"active": "active", "belowValue": "below_value"}
    request_data["config"] = {"price_below_value_notification": {}}
    for key in notification_config_mapping.keys():
        if key not in notification_config:
            log.warning(f"Key {key} was not found in the notification configuration.")
            return None

        notification_config[notification_config_mapping[key]] = notification_config.pop(key)
    notification_config["below_value"] = round(float(notification_config["below_value"]), 2)
    request_data["config"]["price_below_value_notification"] = notification_config

    is_request_data_valid = all(
        [
            isinstance(request_data["token"], str),
            isinstance(request_data["region_identifier"], int) and request_data["region_identifier"] in [0, 1],
            isinstance(request_data["vat_selection"], int) and request_data["vat_selection"] in [0, 1],
            isinstance(request_data["config"]["price_below_value_notification"]["active"], bool),
            isinstance(request_data["config"]["price_below_value_notification"]["below_value"], float),
        ]
    )
    if not is_request_data_valid:
        log.warning("The APNS data was not valid.")
        return None
    return APNSToken(**request_data)
