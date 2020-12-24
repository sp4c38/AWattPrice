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
    log.info("Initiated a new background task to store an APNs token.")
    # Write the token to a file to store it.
    apns_token_manager = APNs_Token_Manager(request_data, db_manager)

    await apns_token_manager.acquire_lock()
    need_to_write_data = await apns_token_manager.set_data()
    if need_to_write_data:
        await apns_token_manager.write_to_database()
    await apns_token_manager.release_lock()

    return

async def validate_token(request: Request):
    # Check if backend can successfully get APNs token from request body.
    request_body = await request.body()
    decoded_body = request_body.decode('utf-8')

    try:
        token_json = json.loads(decoded_body)
        request_data = {"token": None, "config": None}
        request_data["token"] = token_json["apnsDeviceToken"]
        request_data["config"] = {"new_price_available": False}

        # Always need to check with an if statment to ensure backwards-compatibility
        # of users using old AWattPrice versions
        if "newPriceAvailable" in token_json["notificationConfig"]:
            request_data["config"]["new_price_available"] = token_json["notificationConfig"]["newPriceAvailable"]

        if not request_data["token"] == None and not request_data["config"] == None:
            request_data_valid = [False, False]

            if type(request_data["token"]) == str:
                request_data_valid[0] = True

            if type(request_data["config"]["new_price_available"]) == bool:
                request_data_valid[1] = True

            if request_data_valid[0] == True and request_data_valid[1]  == True:
                log.info("APNs data (sent from a client) is valid.")
                return request_data
            else:
                log.info("APNs data (sent from a client) is NOT valid.")
                return None
    except:
        log.warning("Could NOT decode to a valid json when validating clients APNs data.")
        return None
