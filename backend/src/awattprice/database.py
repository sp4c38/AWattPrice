"""Functions to perform database managing tasks."""
from typing import Optional
from typing import Union

from awattprice import defaults
from liteconfig import Config
from loguru import logger
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import create_async_engine


CREATE_ENGINE_KWARGS = {"future": True}


def get_engine(config: Config, async_=False) -> Optional[Union[Engine, AsyncEngine]]:
    """Get either a sync or an async sqlalchemy engine for the app's database.

    :raises FileNotFoundError: If the backends database couldn't be found.
    """
    database_dir = config.paths.data_dir
    database_file = database_dir / defaults.DATABASE_FILE_NAME
    if not database_file.exists():
        raise FileNotFoundError(database_file)

    if async_:
        database_url = f"sqlite+aiosqlite:///{database_file}"
        engine = create_async_engine(database_url)
    else:
        database_url = f"sqlite+pysqlite:///{database_file}"
        engine = create_engine(database_url)

    return engine
