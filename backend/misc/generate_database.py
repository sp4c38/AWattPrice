"""Create a base database which is ready for beeing used by the backend.

Make sure your PYTHONPATH environment variable is set to the awattprice package directory.
"""
import sys

from loguru import logger

from awattprice import configurator
from awattprice import database
from awattprice import defaults
from awattprice import orm

config = configurator.get_config()

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

logger.info("Creating database file.")
db_engine = database.get_awattprice_engine(config, ignore_database_not_found=True)
orm.metadata.bind = db_engine

table_names = orm.metadata.tables.keys()
logger.info(f"Tables going to be created for new database: {', '.join(table_names)}.")
orm.metadata.create_all(bind=db_engine, checkfirst=True)

logger.info(f"Done. You can find the database at {db_path}.")
