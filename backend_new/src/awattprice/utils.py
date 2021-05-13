"""Contains small helper functions which don't fit into a bigger category."""
import asyncio
import json
import sys

from functools import partial
from json import JSONDecodeError
from pathlib import Path
from typing import Callable, Optional, Union

import httpx

from aiofile import async_open
from box import Box, BoxList
from loguru import logger


def async_wrap(func: Callable):
    async def run(*args, loop=None, executor=None, **kwargs) -> Callable:
        if loop is None:
            loop = asyncio.get_event_loop()
        pfunc = partial(func, *args, **kwargs)
        return await loop.run_in_executor(executor, pfunc)

    return run


async def request_url(method: str, url: str, **kwargs) -> httpx.Response:
    """Downloads data at url asynchronous.

    :param **kwargs: Keyword arguments parsed to the httpx.AsyncClient.request() method. This method
        performs the request.
    :returns: Instance of httpx.Response.
    """
    async with httpx.AsyncClient() as client:
        logger.debug(f"Sending {method} request to {url}.")
        response = await client.request(method, url, **kwargs)

    return response


async def store_file(data, file_path: Path):
    """Acquire a lock for the file and store data to it asynchronous."""
    file_dir = file_path.parent
    if not file_dir.exists():
        file_dir.mkdir(parents=True)
    else:
        if file_dir.is_file():
            logger.critical(f"File store path {file_dir} is a file, no directory.")
            sys.exit(1)

    async with async_open(file_path, "w") as file:
        await file.write(data)


async def read_file(file_path: Path) -> Optional[str]:
    """Asynchronous read file.

    :returns: String of the data from the file. None if file is empty.
    """
    async with async_open(file_path, "r") as file:
        file_data = await file.read()

    if len(file_data) == 0:
        return None

    return file_data


async def read_json_file(file_path: Path) -> Optional[Union[Box, BoxList]]:
    """Asynchronous read file and convert to json.

    :returns: Box (if content is dict) or BoxList (if content is list). None if no valid json.
    """
    data_raw = await read_file(file_path)
    try:
        data_json = json.loads(data_raw)
    except JSONDecodeError as err:
        logger.error(f"Couldn't read json file as it is no valid json: {err}.")
        return None

    if isinstance(data_json, dict):
        data = Box(data_json)
    elif isinstance(data_json, list):
        data = BoxList(data_json)

    return data
