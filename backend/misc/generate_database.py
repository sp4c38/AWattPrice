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

cli_params = sys.argv
force_create = False
if len(cli_params) == 2:
    if cli_params[1] == "--force":
        force_create = True

db_path = config.paths.data_dir / defaults.DATABASE_FILE_NAME
if not force_create:
    if db_path.exists():
        logger.info(f"There is already an existing database at {db_path}.")
        sys.exit(0)

# This will create the database file.
logger.info("Creating database file.")
db_engine = get_app_database(config, async_engine=False, force_create=True)
orm.metadata.bind = db_engine

table_names = orm.metadata.tables.keys()
logger.info(f"Tables in new database: {', '.join(table_names)}.")
orm.metadata.create_all(bind=db_engine, checkfirst=True)

logger.info(f"Done. You can find the database at {db_path}.")
