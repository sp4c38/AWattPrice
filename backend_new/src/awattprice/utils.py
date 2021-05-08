"""Contains small helper functions which don't fit into a bigger category."""
from pathlib import Path

from aiofile import async_open
from filelock import FileLock
from loguru import logger


async def lock_store(data, file_path: Path):
    """Acquire the lock of a file, then store data to the file asynchronous."""
    file_dir = file_path.parent
    file_name = file_path.name
    lock_file_name = f"{file_name}.lck"
    lock_file_path = file_dir / lock_file_name

    if not file_dir.exists():
        file_dir.mkdir(parents=True)
    else:
        if file_dir.is_file():
            logger.error(
                f"File store directory {file_dir} is a file, no directory. " "Won't be able to store data."
            )

    lock = FileLock(lock_file_path)
    lock.acquire()

    async with async_open(file_path, "w") as file:
        await file.write(data)

    lock.release()
