"""Helper functions which don't fit into a bigger category."""
import asyncio
import json

from functools import partial
from pathlib import Path
from typing import Callable
from typing import Optional
from typing import Union

import httpx
import jsonschema

from aiofile import async_open
from box import Box
from box import BoxList
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
