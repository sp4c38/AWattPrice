import sys

from typing import Optional

from liteconfig import Config
from loguru import logger
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from awattprice import defaults


def get_app_database(config: Config, async_engine=False, force_create=False) -> Engine:
    """Get the apps database connection with some other objects.

    :param async_engine: Defaults to false. If true this will create a sqlalchemy async engine. If false
        the normal sync engine will be created.
    :param force_create: Don't exit if no database file exists, but instead create the database file.
    :returns Database: Returns an instance of this class.
    """
    db_dir = config.paths.data_dir
    db_file = db_dir / defaults.DATABASE_FILE_NAME
    if not force_create and not db_file.exists():
        logger.error(f"Apps database doesn't exist at {db_file}. Please create it.")
        sys.exit(1)

    create_engine_kwargs = {"future": True}
    if async_engine:
        db_url = f"sqlite+aiosqlite:///{db_file}"
        engine = create_async_engine(db_url, **create_engine_kwargs)
    else:
        db_url = f"sqlite+pysqlite:///{db_file}"
        engine = create_engine(db_url, **create_engine_kwargs)

    return engine
