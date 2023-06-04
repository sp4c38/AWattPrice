"""Functions to perform database managing tasks."""
from pathlib import Path
from typing import Optional
from typing import Union

from awattprice import defaults
from liteconfig import Config
from loguru import logger
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import create_async_engine


CREATE_ENGINE_KWARGS = {"future": True, "echo": False}


def get_engine(database_file: Path, ignore_database_not_found=False, async_=False) -> Optional[Union[Engine, AsyncEngine]]:
    """Get either a sync or an async sqlalchemy engine for the app's database.

    :raises FileNotFoundError: If the backends database couldn't be found.
    """
    if not database_file.exists() and not ignore_database_not_found:
        raise FileNotFoundError(database_file)

    if async_:
        database_url = f"sqlite+aiosqlite:///{database_file}"
        engine = create_async_engine(database_url, **CREATE_ENGINE_KWARGS)
    else:
        database_url = f"sqlite+pysqlite:///{database_file}"
        engine = create_engine(database_url, **CREATE_ENGINE_KWARGS)

    return engine


def get_awattprice_engine(config: Config, ignore_database_not_found=False, async_=False) -> Optional[Union[Engine, AsyncEngine]]:
    database_dir = config.paths.data_dir
    database_file = database_dir / defaults.DATABASE_FILE_NAME
    return get_engine(database_file, ignore_database_not_found=ignore_database_not_found, async_=async_)