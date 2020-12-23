import asyncio
import json
import os
import sqlite3

from box import Box
from filelock import FileLock
from loguru import logger as log
from multiprocessing import Lock
from pathlib import Path


class Token_Database_Manager:
    lock = Lock()

    def connect(self, config):
        database_path = Path(config.file_location.apns_dir).expanduser() / Path("token.db")

        database_dir = database_path.parent
        if not database_dir.expanduser().is_dir():
            log.warning(f"Creating the APNs database directory {database_dir}.")
            os.makedirs(database_dir.expanduser().as_posix())

        self.db = sqlite3.connect(database_path, check_same_thread=False)
        log.info("Connected to sqlite database.")

    def check_table_exists(self):
        cursor = self.db.cursor()
        self.lock.acquire()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS token_storage (
                all_data TEXT PRIMARY KEY NOT NULL
            )""")
        cursor.close()
        self.db.commit()
        self.lock.release()

    def disconnect(self):
        self.db.commit()
        self.db.close()
        log.info("Connection to database was closed.")

class APNs_Token_Manager:
    def __init__(self, token, database_manager):
        self.token = token
        self.data = None
        self.db_manager = database_manager

    def acquire(self):
        self.db_manager.lock.acquire()

    async def acquire_lock(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.acquire)

    def release(self):
        self.db_manager.lock.release()

    async def release_lock(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.release)

    async def add_token(self) -> bool:
        if not self.data:
            self.data = {"tokens": [self.token]}
            return True
        else:
            if not self.token in self.data["tokens"]:
                self.data["tokens"].append(self.token)
                return True
            else:
                return False

    def write_database(self):
        cursor = self.db_manager.db.cursor()
        cursor.execute("SELECT * FROM token_storage;")
        item_count = len(cursor.fetchall())
        new_data = json.dumps(self.data)

        if item_count == 0:
            with self.db_manager.db:
                cursor.execute("INSERT INTO token_storage VALUES(?);", (new_data,))
                self.db_manager.db.commit()
        elif item_count == 1:
            cursor.execute(""" UPDATE token_storage SET all_data = ? WHERE ROWID = ?""", (new_data, 1,))
            self.db_manager.db.commit()


    def read_database(self):
        cursor = self.db_manager.db.cursor()
        items = cursor.execute("SELECT * FROM token_storage;").fetchall()

        if len(items) == 0:
            self.data = None
            return
        elif len(items) > 1:
            log.warning("Found more than one token row in the database. This should never happen!\
                         The first row is used for further reading and writing.")

        raw_data = items[0][0]
        print(raw_data)
        try:
            data = json.loads(raw_data)
            self.data = data
        except Exception as exp:
            log.warning(f"Could not read and parse existing APNs tokens from database: {exp}.")
            self.data = None

    async def read_from_database(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.read_database)

    async def write_to_database(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.write_database)
