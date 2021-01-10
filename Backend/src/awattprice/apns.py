# -*- coding: utf-8 -*-

"""

Code to handle notification configuration from clients used for communication with APNs later.

"""
__author__ = "Léon Becker <lb@space8.me>"
__copyright__ = "Léon Becker"
__license__ = "mit"

import json

from typing import Dict, Optional

from fastapi import Request
from loguru import logger as log

from awattprice.token_manager import APNsTokenManager


async def write_token(request_data, db_manager):
    """Store APNs token configuration to the database."""
    log.info("Initiated a new background task to store an APNs configuration.")
    apns_token_manager = APNsTokenManager(request_data, db_manager)

    await db_manager.acquire_lock()
    need_to_write_data = await apns_token_manager.set_data()
    if need_to_write_data:
        await apns_token_manager.write_to_database()
    await db_manager.release_lock()


def validate_token(request: Request) -> Optional[Dict]:
    """Checks if the backend can successfully read and decode the APNs token configuration
    sent from a client.

    Clarification:
    When refering to APNs token configuration or APNs configuration or token configuration
    the token and all config data (like selected region in app, selected notifications to receive, ...
    is meant.
    """

    try:
        body_json = json.loads(request.decode("utf-8"))
    except json.JSONDecodeError as e:
        log.warning(f"Could not JSON encode the request: {e}")

    request_data = {
        "token": None,
        "region_identifier": None,
        "vat_selection": None,
        "config": None,
    }

    try:
        request_data["token"] = body_json["apnsDeviceToken"]
        request_data["region_identifier"] = body_json["regionIdentifier"]
        request_data["vat_selection"] = body_json["vatSelection"]
        # Set default values which are replaced if certain values are contained in the request body
        request_data["config"] = {
            "price_below_value_notification": {"active": False, "below_value": float(0)}
        }

        # Always check with an if statement to ensure backwards-compatibility (in the future)
        if "priceBelowValueNotification" in body_json["notificationConfig"]:
            # Set price below value notification configuration if included in request body
            below_notification = body_json["notificationConfig"][
                "priceBelowValueNotification"
            ]
            if "active" in below_notification and "belowValue" in below_notification:
                active = below_notification["active"]
                below_value = float(below_notification["belowValue"])
                # Limit below_value to two decimal places.
                # The app normally should already have rounded this number to two decimal places - but to make sure.
                below_value = round(below_value, 2)
                request_data["config"]["price_below_value_notification"][
                    "active"
                ] = active
                request_data["config"]["price_below_value_notification"][
                    "below_value"
                ] = below_value

        if request_data["token"] is not None and request_data["config"] is not None:
            # Validate types
            is_request_data_valid = all([
                isinstance(request_data["token"], str),
                isinstance(request_data["region_identifier"], int) and request_data["region_identifier"] in [0, 1],
                isinstance(request_data["vat_selection"], int) and request_data["vat_selection"] in [0, 1],
                isinstance(request_data["config"]["price_below_value_notification"]["active"], bool),
                isinstance(request_data["config"]["price_below_value_notification"]["below_value"], float),
            ])
        else:
            is_request_data_valid = False

    except KeyError as e:
        log.warning(
            f"Caught a KeyError while validating APNs token: {e}"
        )
        is_request_data_valid = False
    except Exception as e:
        log.warning(
            f"Caught an unknown exception while validating client APNs data: {e}"
        )
        is_request_data_valid = False

    if not is_request_data_valid:
        log.info("APNs data (sent from a client) is NOT valid.")
        request_data = None
    else:
        log.info("APNs data (sent from a client) is valid.")
    return request_data
