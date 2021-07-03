"""Small helper functions."""
from typing import Optional

from liteconfig import Config
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import create_async_engine


def get_async_legacy_engine(config: Config) -> Optional[AsyncEngine]:
    """Get the async engine for the database of the legacy backend.

    :raises FileNotFoundError: If the backends database couldn't be found.
    """
    database_file = config.paths.legacy_database
    if not database_file.exists():
        raise FileNotFoundError(database_file)
    database_url = f"sqlite+aiosqlite:///{database_file}"
    engine = create_async_engine(database_url, future=True)
    return engine
