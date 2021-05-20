"""Create a base database which is ready for beeing used by the backend.

Make sure your PYTHONPATH environment variable is set to the awattprice package directory.
"""
import sys

from loguru import logger

from awattprice import defaults
from awattprice import tables
from awattprice.config import get_config
from awattprice.database import get_app_database

config = get_config()

db_path = config.paths.data_dir / defaults.DATABASE_FILE_NAME
if db_path.exists():
    logger.info(
        f"There is already an existing database at {db_path}. Won't continue as this would be too risky."
    )
    sys.exit(0)

# This will create the database file.
database = get_app_database(config, async_engine=False, force_create=True)
tables.generate_table_classes(database.registry)

database.metadata.create_all(bind=database.engine, checkfirst=False)
