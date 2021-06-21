"""Functions to perform database managing tasks."""
from liteconfig import Config
from loguru import logger
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from awattprice import defaults


CREATE_ENGINE_KWARGS = {"future": True}


def get_database_url(config: Config, async_: bool = False) -> str:
    """Get the apps database connection with some other objects.

    :param async_: If true use aiosqlite async dbapi, if false use pysqlite sync dbapi.
    """
    db_dir = config.paths.data_dir
    db_file = db_dir / defaults.DATABASE_FILE_NAME

    logger.info(f"Database file is {db_file}.")

    if async_ is True:
        db_url = f"sqlite+aiosqlite:///{db_file}"
    else:
        db_url = f"sqlite+pysqlite:///{db_file}"

    return db_url


def get_async_engine(config: Config) -> AsyncEngine:
    """Get an async sqlalchemy engine for the app's database."""
    db_url = get_database_url(config, async_=True)
    engine = create_async_engine(db_url, **CREATE_ENGINE_KWARGS)
    return engine


def get_engine(config: Config) -> Engine:
    """Get sqlalchemy engine for the app's database."""
    db_url = get_database_url(config)
    engine = create_engine(db_url, **CREATE_ENGINE_KWARGS)
    return engine
