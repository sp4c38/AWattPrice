import sys

from dataclasses import dataclass

from liteconfig import Config
from loguru import logger
from sqlalchemy import MetaData
from sqlalchemy.orm import DeclarativeMeta, registry as Registry
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from awattprice import defaults as dflts


@dataclass
class Database:
    engine: AsyncEngine
    metadata: MetaData
    registry: Registry
    BaseClass: DeclarativeMeta


def get_app_database(config: Config) -> Database:
    """Get the apps database connection with some other objects.

    :returns Database: Returns an instance of this class.
    """
    db_dir = config.paths.data_dir
    db_file = db_dir / dflts.DATABASE_FILE_NAME
    if not db_file.exists():
        logger.error(f"Apps database doesn't exist at {db_file}. Please create it.")
        sys.exit(1)

    db_path = f"sqlite+aiosqlite:///{db_file}"
    engine = create_async_engine(db_path, future=True)

    metadata = MetaData(engine)

    registry = Registry(metadata)

    BaseClass = registry.generate_base()

    database = Database(engine, metadata, registry, BaseClass)

    return database
