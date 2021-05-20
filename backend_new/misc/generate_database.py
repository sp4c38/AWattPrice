"""Create a base database which is ready for beeing used by the backend.

Make sure your PYTHONPATH environment variable is set to the awattprice package directory.
"""
import sys

from loguru import logger
from sqlalchemy import MetaData

from awattprice import defaults
from awattprice import orm
from awattprice.config import get_config
from awattprice.database import get_app_database

config = get_config()

db_path = config.paths.data_dir / defaults.DATABASE_FILE_NAME
if db_path.exists():
    logger.info(f"There is already an existing database at {db_path}.")
    sys.exit(0)

# This will create the database file.
logger.info("Creating database file.")
db_engine = get_app_database(config, async_engine=False, force_create=True)
orm.metadata.bind = db_engine

table_names = orm.metadata.tables.keys()
logger.info(f"Creating tables: {', '.join(table_names)}.")
orm.metadata.create_all(bind=db_engine, checkfirst=False)

logger.info(f"Done. You can find the new database at {db_path}.")
