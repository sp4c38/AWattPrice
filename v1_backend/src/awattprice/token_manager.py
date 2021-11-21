# -*- coding: utf-8 -*-

"""

Manages database entries for notification configuration.

"""
__author__ = "Léon Becker <lb@space8.me>"
__copyright__ = "Léon Becker"
__license__ = "mit"

import asyncio
import json
import os
import sqlite3

from loguru import logger as log
from multiprocessing import Lock
from pathlib import Path

from awattprice.types import APNSToken

class APNsTokenManager:
    def __init__(self, token_data: APNSToken, database_manager):
        self.token_data = token_data.dict()
        self.final_data = None

    def set_data(self):
        # Read existing data and appropriately create the final data which will be later written to the database
        self.final_data = {"config": self.token_data["config"]}