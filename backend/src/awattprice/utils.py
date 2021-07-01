"""Helper functions which don't fit into a bigger category."""
import asyncio

from functools import partial
from typing import Callable
from typing import Union

import jsonschema

from box import Box
from fastapi import HTTPException
from loguru import logger


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
