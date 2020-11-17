# -*- coding: utf-8 -*-

"""

Discovergy shared helper code

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

import gzip
import json
import os
import re
import sys

from contextlib import ContextDecorator
from pathlib import Path
from timeit import default_timer
from typing import Any, Callable, Dict, List, NamedTuple, Optional, Union

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


def start_logging(config: Box) -> None:
    """Start console and file logging"""
    log_dir = Path(config.file_location.log_dir).expanduser()
    if not log_dir.is_dir():
        sys.stderr.write(f"Could not find the log dir {log_dir}. Creating it ...\n")
        os.makedirs(log_dir.as_posix())
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
                "sink": log_dir / "awattprice_{time}.log",
                "rotation": "1 day",
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
                "The permissions were changed to -rw------- for you. ".format(path, oct(file_stat.st_mode))
            )
            return True
    return False


def read_data(*, file_path: Path) -> Optional[Box]:
    """Return the data read from file_path."""
    if not file_path.is_file():
        return None
    with file_path.open() as fh:
        try:
            data = json.load(fh)
        except Exception as e:
            log.warning(f"Could not read and parse data from {file_path}: {e}.")
            return None
    return Box(data)


def write_data(*, data: Union[List, Dict, Box], file_path: Path, compress: bool = False) -> None:
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
    with lock.acquire():
        with opener(file_path.expanduser().as_posix(), "wb") as fh:
            fh.write(json.dumps(data).encode("utf-8"))
