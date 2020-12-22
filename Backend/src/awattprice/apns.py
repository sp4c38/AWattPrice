import asyncio
import fcntl
import json
import queue

from box import Box
from contextlib import asynccontextmanager
from fastapi import Request
from filelock import FileLock
from loguru import logger as log
from pathlib import Path

from awattprice.config import read_config
from awattprice.utils import read_data, write_data

class APNs_Token_Manager:
    def __init__(self, token, file_path, lock_file_path):
        self.token = token
        self.file_path = file_path
        self.lock = FileLock(lock_file_path.as_posix())
        self.data = None

    def acquire(self):
        self.lock.acquire()

    async def acquire_lock(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.acquire)

    def release(self):
        self.lock.release()

    async def release_lock(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.release)

    async def add_token(self) -> bool:
        if not self.data:
            self.data = {"tokens": [self.token]}
            return true
        else:
            if not self.token in self.data["tokens"]:
                self.data["tokens"].append(self.token)
                return True
            else:
                return False

    def write_file(self):
        with open(self.file_path.expanduser().as_posix(), "wb") as fh:
            fh.write(json.dumps(self.data).encode("utf-8"))

    def read_file(self):
        if not self.file_path.is_file():
            return None
        raw_data = open(self.file_path, "r").read()
        try:
            data = json.loads(raw_data)
            self.data = data
        except Exception as e:
            log.warning(f"Could not read and parse APNs from {self.file_path}: {e}.")
            self.data = None

    async def read_from_file(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.read_file)

    async def write_to_file(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.write_file)


async def write_token(token: str):
    log.info("Initiated a new background task to store an APNs token.")
    # Write the token to a file to store it.
    config = read_config()
    apns_storage = Path(config.file_location.apns_dir).expanduser() / Path("tokens.json")
    lock_file_path = apns_storage.parent / Path("tokens.json.lck")

    apns_token_manager = APNs_Token_Manager(token, apns_storage, lock_file_path)

    await apns_token_manager.acquire_lock()
    await apns_token_manager.read_from_file()
    token_is_new = await apns_token_manager.add_token()
    if token_is_new:
        await apns_token_manager.write_to_file()
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
