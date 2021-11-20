"""Check for entries which are only present in the old database but not present in the new database and copy those.
Will only check for complete entries to differ between databases, not for certain attributes of entries to differ.
"""
import asyncio
import json
import sys

from collections import namedtuple

from awattprice import configurator
from awattprice.database import get_awattprice_engine
from awattprice.database import get_engine
from awattprice.defaults import Region
from awattprice.orm import Token
from awattprice.orm import PriceBelowNotification
from box import Box
from loguru import logger
from sqlalchemy import Column
from sqlalchemy import Boolean
from sqlalchemy import Enum
from sqlalchemy import Integer
from sqlalchemy import MetaData
from sqlalchemy import select
from sqlalchemy import String
from sqlalchemy import Table
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import registry as Registry
from sqlalchemy.types import TypeDecorator

COPY_DATABASE_ENTRIES_SERVICE_NAME = "copy_database_entries"

NewDatabase_EntryCollection = namedtuple("NewDatabase_EntryCollection", ["token", "price_below_notification"])

metadata = MetaData()
registry = Registry(metadata)
Base = registry.generate_base()


class JSONField(TypeDecorator):
    impl = String

    def process_result_value(self, value, dialect):
        try:
            decoded_json = json.loads(value)
            return Box(decoded_json)
        except json.JSONDecodeError as exc:
            return None


region_mapping = {0: Region.DE, 1: Region.AT}


class IntegerRegionIdentifierField(TypeDecorator):
    impl = Integer

    def process_result_value(self, value, dialect):
        return region_mapping.get(value, None)


class OldDatabase_TokenStorage(Base):
    __tablename__ = "token_storage"

    token = Column(String, primary_key=True)
    region_identifier = Column(IntegerRegionIdentifierField)
    vat_selection = Column(Boolean)
    configuration = Column(JSONField)


async def get_old_database_entries(old_database: AsyncEngine) -> [OldDatabase_TokenStorage]:
    async with AsyncSession(old_database) as session:
        raw_results = await session.execute(select(OldDatabase_TokenStorage))

    entries = raw_results.scalars().all()
    return entries


async def get_old_database_entries_to_be_copied(
    new_database: AsyncEngine, old_database_entries: [OldDatabase_TokenStorage]
):
    old_database_tokens = [entry.token for entry in old_database_entries]

    statment = select(Token).where(Token.token.in_(old_database_tokens))
    async with AsyncSession(new_database) as session:
        raw_results = await session.execute(statment)
    new_database_matching_entries = raw_results.scalars().all()
    new_database_matching_tokens = [entry.token for entry in new_database_matching_entries]

    old_database_non_matching_entries = []
    for entry in old_database_entries:
        if entry.token not in new_database_matching_tokens:
            old_database_non_matching_entries.append(entry)

    return old_database_non_matching_entries


def convert_to_new_database_entries(
    old_database_entries: [OldDatabase_TokenStorage],
) -> [NewDatabase_EntryCollection]:
    """Convert the entries of the old database to entries for the new database."""
    new_entries = []
    for old_database_entry in old_database_entries:
        if not old_database_entry.region_identifier:
            continue

        new_token = Token(
            token=old_database_entry.token,
            region=old_database_entry.region_identifier,
            tax=old_database_entry.vat_selection,
        )

        if old_database_entry.configuration:
            old_database_price_below_notification = (
                old_database_entry.configuration.config.price_below_value_notification
            )
            new_price_below_notification = PriceBelowNotification(
                active=old_database_price_below_notification.active,
                below_value=old_database_price_below_notification.below_value,
            )
            new_entry = NewDatabase_EntryCollection(
                token=new_token, price_below_notification=new_price_below_notification
            )
        else:
            new_entry = NewDatabase_EntryCollection(token=new_token, price_below_notification=None)

        new_entries.append(new_entry)

    return new_entries


async def copy_entries(new_database: AsyncEngine, new_database_entries: [NewDatabase_EntryCollection]):
    async with AsyncSession(new_database) as session:
        token_entries = [collection.token for collection in new_database_entries]

        session.add_all(token_entries)
        await session.flush()

        for entry in new_database_entries:
            if entry.price_below_notification:
                entry.price_below_notification.token_id = entry.token.token_id

        price_below_notification_entries = [
            collection.price_below_notification
            for collection in new_database_entries
            if collection.price_below_notification
        ]
        session.add_all(price_below_notification_entries)

        await session.commit()

        logger.info(
            f"Copied {len(token_entries)} new token entries "
            f"and {len(price_below_notification_entries)} new price below notification entries to the new database."
        )


async def main():
    config = configurator.get_config()
    configurator.configure_loguru(COPY_DATABASE_ENTRIES_SERVICE_NAME, config)

    if config.paths.old_database is None:
        logger.error("No old backend configured in the config file.")
        sys.exit(1)

    new_database = get_awattprice_engine(config, async_=True)
    old_database = get_engine(config.paths.old_database, async_=True)

    old_database_entries = await get_old_database_entries(old_database)
    if len(old_database_entries) == 0:
        logger.info("No entries in the old database.")
        sys.exit(0)

    old_database_entries_to_copy = await get_old_database_entries_to_be_copied(new_database, old_database_entries)
    new_database_entries = convert_to_new_database_entries(old_database_entries_to_copy)

    await copy_entries(new_database, new_database_entries)


if __name__ == "__main__":
    asyncio.run(main())
