"""Helper functions which don't fit into a bigger category."""
import asyncio
import os
import tempfile

from contextlib import contextmanager
from decimal import Decimal
from functools import partial
from pathlib import Path
from typing import Callable
from typing import Union

import jsonschema

from box import Box
from fastapi import HTTPException
from filelock import FileLock
from loguru import logger
from loguru._logger import Logger

from awattprice import defaults


class ExtendedFileLock(FileLock):
    def __init__(self, *args, **kwargs):
        # Acquires happen in an executor thread, releases on the event-loop thread.
        # filelock defaults to thread-local state, which can leave the OS lock held.
        kwargs.setdefault("thread_local", False)
        super().__init__(*args, **kwargs)

    @contextmanager
    def context(self, acquire=True):
        """Better context manager.

        :param acquire: If true the lock will be acquired on context enter, else won't be acquired.
        """
        if acquire:
            self.acquire()
        try:
            yield
        finally:
            self.release()


def async_wrap(func: Callable):
    """Wrap a synchronous running function to make it run asynchronous."""

    async def run(*args, loop=None, executor=None, **kwargs) -> Callable:
        """Run sync function async."""
        if loop is None:
            loop = asyncio.get_event_loop()
        pfunc = partial(func, *args, **kwargs)
        return await loop.run_in_executor(executor, pfunc)

    return run


def atomic_write_bytes(path: Path, data: bytes) -> None:
    """Write bytes by replacing the target only after the full payload is durable."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=path.parent,
    )
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp_path, path)
    finally:
        try:
            os.unlink(temp_path)
        except FileNotFoundError:
            pass


async def async_atomic_write_bytes(path: Path, data: bytes) -> None:
    """Async wrapper for atomic byte writes."""
    await asyncio.to_thread(atomic_write_bytes, path, data)


async def async_atomic_write_text(path: Path, text: str) -> None:
    """Async wrapper for atomic text writes."""
    await async_atomic_write_bytes(path, text.encode())


def http_exc_validate_json_schema(body: Union[Box, dict, list], schema: dict, http_code: int):
    """Validate a json body against a schema and throw exception if body doesn't match.
    :raises HTTPException: with the parsed error code if the body doesn't match the schema.
    """
    try:
        jsonschema.validate(body, schema)
    except jsonschema.ValidationError as exc:
        logger.warning(f"Body doesn't match correct schema: {exc}.")
        raise HTTPException(http_code) from exc


def log_attempts(logger: Callable, service_name: str):
    """Before strategy for tenacity to log attempts."""

    def log_single_attempt(retry_state):
        attempt = retry_state.attempt_number
        if attempt != 1:
            logger(f"Performing attempt number {attempt} for \'{service_name}\'.")

    return log_single_attempt


def unitmwh_to_subunitkwh(value: Decimal, subunits_per_currency_unit: int) -> Decimal:
    """Convert currency-unit per MWh to subunit per kWh."""
    converted_value = value * Decimal(str(subunits_per_currency_unit)) * Decimal("0.001")
    return converted_value


def round_subunitkwh(value: Union[float, Decimal]) -> Union[float, Decimal]:
    """Round subunit per kWh to the natural decimal places."""
    rounded_value = round(value, defaults.PRICE_SUBUNIT_ROUNDING_PLACES)
    return rounded_value
