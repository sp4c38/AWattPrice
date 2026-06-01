"""Helper functions which don't fit into a bigger category."""
import asyncio
import json
import os
import tempfile

from contextlib import contextmanager
from decimal import Decimal
from pathlib import Path
from typing import Callable
from typing import Optional
from typing import Union

import jsonschema
import arrow

from box import Box
from fastapi import HTTPException
from filelock import FileLock
from filelock import Timeout
from loguru import logger

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


async def acquire_file_lock_immediate(
    lock: ExtendedFileLock,
    timeout: float = defaults.PRICE_DATA_REFRESH_LOCK_TIMEOUT,
) -> bool:
    """Acquire a file lock immediately or wait up to timeout.

    Returns true when the caller acquired the lock immediately. Returns false
    when the caller had to wait, so it should reread cached data instead of
    doing duplicate work.
    """
    try:
        await asyncio.to_thread(lock.acquire, timeout=0)
    except Timeout:
        pass
    else:
        return True

    if timeout <= 0:
        raise Timeout(lock.lock_file)

    await asyncio.to_thread(lock.acquire, timeout=timeout)
    return False


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


def load_timestamp_attrs(path: Path, target: object, attrs: tuple[str, ...]) -> tuple[Optional[Exception], dict[str, Exception]]:
    """Load integer timestamps from JSON into matching attributes on target."""
    try:
        raw = json.loads(path.read_text())
    except Exception as exc:
        return exc, {}

    field_errors = {}
    for attr in attrs:
        ts = raw.get(attr)
        if ts is None:
            continue
        try:
            setattr(target, attr, arrow.get(int(ts)))
        except Exception as exc:
            field_errors[attr] = exc

    return None, field_errors


def save_timestamp_attrs(path: Path, source: object, attrs: tuple[str, ...], service_name: str):
    """Persist timestamp attributes as compact JSON."""
    data = {
        attr: getattr(source, attr).int_timestamp if getattr(source, attr) is not None else None
        for attr in attrs
    }
    try:
        path.write_text(json.dumps(data))
    except OSError as exc:
        logger.warning(f"Couldn't save {service_name} state: {exc}.")


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
