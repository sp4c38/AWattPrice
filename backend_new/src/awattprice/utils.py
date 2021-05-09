"""Contains small helper functions which don't fit into a bigger category."""
import json
import sys

from json import JSONDecodeError
from pathlib import Path

from aiofile import async_open
from filelock import FileLock
from loguru import logger


async def lock_store_file(data, file_path: Path):
    """Acquire a lock for the file and store data to it asynchronous."""
    file_dir = file_path.parent
    file_name = file_path.name
    lock_file_name = f"{file_name}.lck"
    lock_file_path = file_dir / lock_file_name

    if not file_dir.exists():
        file_dir.mkdir(parents=True)
    else:
        if file_dir.is_file():
            logger.critical(f"File store path {file_dir} is a file, no directory.")
            sys.exit(1)

    lock = FileLock(lock_file_path)
    lock.acquire()
    async with async_open(file_path, "w") as file:
        await file.write(data)
    lock.release()

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
        data = json.loads(data_raw)
    except JSONDecodeError as err:
        logger.error("Couldn't read json file as it is no valid json: {err}.")

    if isinstance(data, dict):
        data_boxed = Box(data_json)
    elif isinstance(data, list):
        data_boxed = BoxList(data_json)

    return data_boxed
