# -*- coding: utf-8 -*-

"""

Discovergy shared helper code

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

import asyncio
import gzip
import json
import os
import re
import sys

from contextlib import ContextDecorator
from pathlib import Path
from timeit import default_timer
from typing import Any, Callable, Dict, List, NamedTuple, Optional, Union

import aiofiles
import arrow  # type: ignore

from box import Box  # type: ignore
from filelock import FileLock
from loguru import logger as log
from tenacity import _utils  # type: ignore


class TimeStampedValue(NamedTuple):
    timestamp: float
    value: Any


class ValueUnit(NamedTuple):
    value: Union[float, int]
    unit: str


class measure_duration(ContextDecorator):
    """A context manager that measures time from enter to exit."""

    def __enter__(self):
        self.start = default_timer()
        return self

    def __exit__(self, *exc):
        self.duration = default_timer() - self.start
        return False


def start_logging(config: Box, for_scheduled_request: bool = False) -> None:
    """Start console and file logging"""
    log_dir = Path(config.file_location.log_dir).expanduser()

    if not log_dir.is_dir():
        sys.stderr.write(f"Could not find the log dir {log_dir}. Creating it ...\n")
        os.makedirs(log_dir.as_posix())
    if for_scheduled_request is False:
        log_path = log_dir / "awattprice.log"
    else:
        log_path = log_dir / "scheduled_request.log"

    log_config = {
        "handlers": [
            {
                "sink": sys.stderr,
                "format": "{time:YYYY-MM-DD HH:mm:ss} | <level>{level}</level> | {message}",
                "colorize": True,
                "level": "DEBUG",
                "backtrace": True,
            },
            {
                "sink": log_path,
                "rotation": "100 KB",
                "level": "TRACE",
                "compression": "gz",
                "format": "{time:YYYY-MM-DDTHH:mm:ss} | {level} | {message}",
                "backtrace": True,
                "serialize": False,
            },
        ],
        "extra": {"user": "someone"},
    }
    log.configure(**log_config)  # type: ignore


def before_log(logger: Any, log_level: str) -> Callable:
    """Before call strategy that logs to some logger the attempt."""

    def log_it(retry_state):
        logger = getattr(log, log_level)
        logger(
            f"Starting call to '{_utils.get_callback_name(retry_state.fn)}', "
            f"this is the {_utils.to_ordinal(retry_state.attempt_number)} time calling it."
        )

    return log_it


def str2bool(value: str) -> bool:
    """Return the boolean value of the value given as a str."""
    if value.lower() in ["true", "1", "t", "y", "yes", "yeah"]:
        return True
    return False


def verify_file_permissions(path: Path) -> bool:
    """Return (True|False) if the file system access rights are set to current user only."""
    if path.is_file:
        file_stat = path.stat()
        if file_stat.st_uid != os.getuid():
            return False

        if re.match(r"0o*100[0-6]00", oct(file_stat.st_mode)):
            return True
        try:
            os.chmod(path, 0o600)
        except OSError:
            log.error(
                f"Tried to change the permissions of {path} but failed. "
                "Please fix the permissions to max. 0600 yourself!"
            )
            return False
        else:
            log.warning(
                "The file {} didn't have secure file permissions {}. "
                "The permissions were changed to -rw------- for you. ".format(
                    path, oct(file_stat.st_mode)
                )
            )
            return True
    return False


def async_acquire_lock_helper(lock, timeout):
    lock.acquire(timeout=timeout)


async def async_acquire_lock(lock, timeout):
    # Acquire locks asynchronous.
    # If locks aren't acquired asynchronous, it could leed to one task successfully
    # acquiring the lock. Running some await tasks with the lock acquired.
    # At the same time a other task tries to get the lock and waits because it can't
    # get it. Because this waiting isn't awaited the backend won't resume any other tasks anymore.
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, async_acquire_lock_helper, lock, timeout)


async def read_data(*, file_path: Path) -> Optional[Box]:
    """Return the data read from file_path."""
    if not file_path.is_file():
        return None
    lock = FileLock(f"{file_path.as_posix()}.lck")
    with lock.acquire():
        async with aiofiles.open(file_path) as fh:  # type: ignore
            raw_data = ""
            async for line in fh:
                raw_data += line
    try:
        data = json.loads(raw_data)
    except Exception as e:
        log.warning(f"Could not read and parse data from {file_path}: {e}.")
        return None
    return Box(data)


async def write_data(
    *, data: Union[List, Dict, Box], file_path: Path, compress: bool = False
) -> None:
    """Write the gz-iped raw data to file_path."""
    dst_dir = file_path.parent
    if not dst_dir.expanduser().is_dir():
        log.warning(f"Creating the data destination directory {dst_dir}.")
        os.makedirs(dst_dir.expanduser().as_posix())
    if compress:
        opener: Callable = gzip.open
    else:
        opener = open
    lock = FileLock(f"{file_path.as_posix()}.lck")
    await async_acquire_lock(lock, None)
    with opener(file_path.expanduser().as_posix(), "wb") as fh:
        fh.write(json.dumps(data).encode("utf-8"))
    lock.release()


def check_data_needs_update(data: Box, config: Box):
    need_update = True
    now = arrow.utcnow()
    last_update = data.meta.update_ts
    # Only poll every config.poll.awattar seconds
    if now.timestamp > last_update + int(config.poll.awattar):
        last_entry = max([d.start_timestamp for d in data.prices])
        need_update = any(
            [
                # Should trigger if there are less than this amount of future energy price points.
                len([True for e in data.prices if e.start_timestamp > now.timestamp])
                < int(config.poll.if_less_than),
            ]
        )
    else:
        need_update = False

    return need_update
