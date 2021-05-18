from liteconfig import Config
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from awattprice import defaults as dflts


def connect_database(config: Config) -> AsyncEngine:
    """Create a sqlalchemy connection to the backends database."""
    db_dir = config.paths.data_dir
    db_file = db_dir / dflts.DATABASE_FILE_NAME

    db_path = f"sqlite+aiosqlite:///{db_file}"
    engine = create_async_engine(db_path, future=True)

    return engine