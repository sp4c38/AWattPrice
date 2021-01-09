# -*- coding: utf-8 -*-

"""

Code to handle notification configuration from clients used for communication with APNs later.

"""
__author__ = "Léon Becker <lb@space8.me>"
__copyright__ = "Léon Becker"
__license__ = "mit"

import asyncio
import json
import sqlite3

from fastapi import Request
from loguru import logger as log
from pathlib import Path

from awattprice.config import read_config
from awattprice.token_manager import APNs_Token_Manager
from awattprice.utils import read_data, write_data


async def write_token(request_data, db_manager):
    # Store APNs token configuration to the database
    log.info("Initiated a new background task to store an APNs configuration.")
    apns_token_manager = APNs_Token_Manager(request_data, db_manager)

    await db_manager.acquire_lock()
    need_to_write_data = await apns_token_manager.set_data()
    if need_to_write_data:
        await apns_token_manager.write_to_database()
    await db_manager.release_lock()


async def validate_token(request: Request):
    # Checks if the backend can successfully read and decode the APNs token configuration
    # sent from a client.

    # Clarification:
    # When refering to APNs token configuration or APNs configuration or token configuration
    # the token and all config data (like selected region in app, selected notifications to receive, ...
    # is meant.

    request_body = await request.body()
    decoded_body = request_body.decode("utf-8")

    try:
        body_json = json.loads(decoded_body)

        request_data = {
            "token": None,
            "region_identifier": None,
            "vat_selection": None,
            "config": None,
        }
        request_data["token"] = body_json["apnsDeviceToken"]
        request_data["region_identifier"] = body_json["regionIdentifier"]
        request_data["vat_selection"] = body_json["vatSelection"]
        # Set default values which are replaced if certain values are contained in the request body
        request_data["config"] = {
            "price_below_value_notification": {"active": False, "below_value": float(0)}
        }

        # Always check with an if statment to ensure backwards-compatibility (in the future)
        if "priceBelowValueNotification" in body_json["notificationConfig"]:
            # Set price below value notification configuration if included in request body
            below_notification = body_json["notificationConfig"][
                "priceBelowValueNotification"
            ]
            if "active" in below_notification and "belowValue" in below_notification:
                active = below_notification["active"]
                below_value = float(below_notification["belowValue"])
                # Limit below_value to two decimal places.
                # The app normally should already have rounded this number to two decimal places - but make sure.
                below_value = round(below_value, 2)
                request_data["config"]["price_below_value_notification"][
                    "active"
                ] = active
                request_data["config"]["price_below_value_notification"][
                    "below_value"
                ] = below_value

        if not request_data["token"] == None and not request_data["config"] == None:
            request_data_valid = True

            # Validate types
            if not isinstance(request_data["token"], str):
                request_data_valid = False
            if not isinstance(
                request_data["region_identifier"], int
            ) or not request_data["region_identifier"] in [0, 1]:
                request_data_valid = False
            if not isinstance(request_data["vat_selection"], int) or not request_data[
                "vat_selection"
            ] in [0, 1]:
                request_data_valid = False
            if not isinstance(
                request_data["config"]["price_below_value_notification"]["active"], bool
            ):
                request_data_valid = False
            if not isinstance(
                request_data["config"]["price_below_value_notification"]["below_value"],
                float,
            ):
                request_data_valid = False

            if request_data_valid:
                log.info("APNs data (sent from a client) is valid.")
                return request_data
            else:
                log.info("APNs data (sent from a client) is NOT valid.")
                return None
    except Exception as exp:
        log.warning(
            "Could NOT decode to a valid json when validating client APNs data."
        )
        return None
