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
        # Connect to the database

        database_path = Path(config.file_location.apns_dir).expanduser() / Path("token.db")

        database_dir = database_path.parent
        if not database_dir.expanduser().is_dir():
            log.warning(f"Creating the APNs database directory {database_dir}.")
            os.makedirs(database_dir.expanduser().as_posix())

        self.db = sqlite3.connect(database_path, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        log.info("Connected to sqlite database.")

    def check_table_exists(self):
        # Ensure that table in which APNs token configuration is stored exists.

        cursor = self.db.cursor()
        self.lock.acquire()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS token_storage (
                token TEXT PRIMARY KEY NOT NULL,
                region_identifier INTEGER NOT NULL,
                vat_selection INTEGER NOT NULL,
                configuration TEXT NOT NULL
            )""")
        cursor.close()
        self.db.commit()
        self.lock.release()

    def acquire(self):
        # Acquire a custom program-only lock to prevent multiple tasks
        # writing to the database at the same time.
        self.lock.acquire()

    async def acquire_lock(self):
        # Run synchronous acquire asynchronous
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.acquire)

    def release(self):
        # Release custom program-only lock.
        # After this other tasks will be able to write to the database.
        self.lock.release()

    async def release_lock(self):
        # Run synchronous release asynchronous

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.release)

    def disconnect(self):
        # Disconnect from the database by writing all changes and closing the connection.

        self.db.commit()
        self.db.close()
        log.info("Connection to database was closed.")

class APNs_Token_Manager:
    def __init__(self, token_data, database_manager):
        self.token_data = token_data
        self.final_data = None
        self.db_manager = database_manager
        self.is_new_token = False # Is set later

    def write_database(self):
        # Write data to associated database

        cursor = self.db_manager.db.cursor()

        if self.is_new_token:
            # Completely new token and configuration
            encoded_config = json.dumps(self.final_data)
            with self.db_manager.db:
                cursor.execute("INSERT INTO token_storage VALUES(?, ?, ?, ?);",
                    (self.token_data["token"], self.token_data["region_identifier"],
                     self.token_data["vat_selection"], encoded_config,))
            log.info("Stored a new APNs token and config.")
        else:
            # Existing token updates notification configuration
            encoded_config = json.dumps(self.final_data)
            with self.db_manager.db:
                cursor.execute(""" UPDATE token_storage SET region_identifier = ?, vat_selection = ?, configuration = ? WHERE token = ?""",
                              (self.token_data["region_identifier"], self.token_data["vat_selection"], encoded_config, self.token_data["token"],))
            log.info("Updated to a new APNs config.")

        cursor.close()
        self.db_manager.db.commit()

    def set_data_task(self):
        # Read existing data and appropriately create the final data which will be later written to the database
        cursor = self.db_manager.db.cursor()
        token = self.token_data["token"]
        items = cursor.execute("SELECT * FROM token_storage WHERE token = ? LIMIT 1;", (token,)).fetchall()

        if len(items) == 0:
            self.is_new_token = True
            self.final_data = {"config": self.token_data["config"]}
            log.info("New APNs token and configuration was sent from a client.")
            cursor.close()
            return True
        elif len(items) == 1:
            new_config_raw = json.dumps({"config": self.token_data["config"]})
            if (not (items[0][1] == self.token_data["region_identifier"]) or
                not (items[0][2] == self.token_data["vat_selection"]) or
                not (items[0][3] == new_config_raw)):
                self.is_new_token = False # Just new config but no new token
                self.final_data = {"config": self.token_data["config"]}
                log.info("Client requested to update existing APNs configuration.")
                return True
            else:
                log.warning("A client resent his APNs token and configuration. "\
                            "They are same as already stored on the servers APNs database. "\
                            "This shouldn't happen because only new APNs configuration (and tokens) "\
                            "should be sent from the client-side.")
                cursor.close()
                return False
        cursor.close()
        return False

    def remove_entry(self):
        cursor = self.db_manager.db.cursor()
        cursor.execute("DELETE FROM token_storage WHERE token = ?", (self.token_data["token"],))
        cursor.close()
        self.db_manager.db.commit()

    async def remove_entry_from_database(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.remove_entry)

    async def set_data(self):
        # Run synchronous set_data_task asynchronous
        loop = asyncio.get_event_loop()
        need_to_write_data = await loop.run_in_executor(None, self.set_data_task)
        return need_to_write_data

    async def write_to_database(self):
        # Run synchronous write_database asynchronous
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.write_database)
