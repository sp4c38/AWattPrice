"""Helper functions which don't fit into a bigger category."""
import asyncio

from contextlib import contextmanager
from decimal import Decimal
from functools import partial
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
    @contextmanager
    def context(self, acquire=True):
        """Bettern context manager.

        :param acquire: If true the lock will be acquired on context enter, else won't be acquired.
        """
        if acquire:
            self.acquire()
        yield
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


def http_exc_validate_json_schema(body: Union[Box, dict, list], schema: dict, http_code: int):
    """Validate a json body against a schema and throw exception if body doesn't match.
    :raises HTTPException: with the parsed error code if the body doesn't match the schema.
    """
    try:
        jsonschema.validate(body, schema)
    except jsonschema.ValidationError as exc:
        logger.warning(f"Body doesn't match correct schema: {exc}.")
        raise HTTPException(http_code) from exc


def log_attempts(logger: Callable):
    """Before strategy for tenacity to log attempts."""

    def log_single_attempt(retry_state):
        attempt = retry_state.attempt_number
        if attempt != 1:
            logger(f"Performing attempt number {attempt}.")

    return log_single_attempt


def euromwh_to_ctkwh(value: Decimal) -> Decimal:
    """Convert euro per mwh to cent per kwh."""
    converted_value = value * defaults.EURMWH_TO_CENTWKWH
    return converted_value


def round_ctkwh(value: Union[float, Decimal]) -> Union[float, Decimal]:
    """Round ct per kwh to the natual decimal places."""
    rounded_value = round(value, defaults.CENT_KWH_ROUNDING_PLACES)
    return rounded_value
