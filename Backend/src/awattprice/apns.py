import asyncio
import json
import sqlite3

from fastapi import Request
from loguru import logger as log
from pathlib import Path

from awattprice.config import read_config
from awattprice.token_manager import APNs_Token_Manager
from awattprice.utils import read_data, write_data

async def write_token(token: str, db_manager):
    log.info("Initiated a new background task to store an APNs token.")
    # Write the token to a file to store it.
    apns_token_manager = APNs_Token_Manager(token, db_manager)

    await apns_token_manager.acquire_lock()
    await apns_token_manager.read_from_database()
    token_is_new = await apns_token_manager.add_token()
    if token_is_new:
        await apns_token_manager.write_to_database()
    await apns_token_manager.release_lock()

    if token_is_new:
        log.info("Added new APNs token to disk.")

    return

async def validate_token(request: Request) -> str:
    # Check if backend can successfully get APNs token from request body.
    request_body = await request.body()
    decoded_body = request_body.decode('ascii')

    try:
        token_json = json.loads(decoded_body)
        token = token_json["apnsDeviceToken"]
        if token and type(token) == str:
            log.info("Successfully decoded and read user APNs token.")
            return token
        else:
            log.warning("Could not decode and read a valid json when validating users APNs token.")
            return None
    except:
        log.warning("Could not decode and read a valid json when validating users APNs token.")
        return None
