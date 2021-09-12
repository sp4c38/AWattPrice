# Transfer token settings and price below notification settings from the old database to the new database.
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

TRANSFER_DATABASE_SERVICE_NAME = "transfer_database"

metadata = MetaData()
registry = Registry(metadata)
Base = registry.generate_base()

NewEntryPair = namedtuple("NewEntryPair", ["token", "price_below_notification"])

class JSONField(TypeDecorator):
	impl = String

	def process_result_value(self, value, dialect):
		try:
			return Box(json.loads(value))
		except json.JSONDecodeError as exc:
			logger.error(f"Couldn't decode json field {value}: {exc}.")
			return None

class RegionIdentifierField(TypeDecorator):
	impl = Integer

	def process_result_value(self, value, dialect):
		if value == 0:
			return Region.DE
		elif value == 1:
			return Region.AT
		else:
			return None


class OldTokenStorage(Base):
	__tablename__ = "token_storage"

	token = Column(String, primary_key=True)
	region_identifier = Column(RegionIdentifierField)
	vat_selection = Column(Boolean)
	configuration = Column(JSONField)


async def get_old_entries(old_database: AsyncEngine) -> list:
	async with AsyncSession(old_database) as session:
		raw_results = await session.execute(select(OldTokenStorage))

	entries = raw_results.scalars().all()
	return entries

def convert_to_new_entries(old_entries: list[Box]) -> list:
	"""Convert the entries of the old database to table row entries for the new database."""
	new_entries = []
	for notification_config in old_entries:
		new_token = Token(
			token=notification_config.token,
			region=notification_config.region_identifier,
			tax=notification_config.vat_selection
		)
		price_below_config = notification_config.configuration.config.price_below_value_notification
		new_price_below_notification = PriceBelowNotification(
			active=price_below_config.active,
			below_value=price_below_config.below_value
		)
		new_entry = NewEntryPair(token=new_token, price_below_notification=new_price_below_notification)
		new_entries.append(new_entry)

	return new_entries

async def transfer_entries(old_entries: list[OldTokenStorage], old_database: AsyncEngine, converted_entries: list[NewEntryPair], new_database: AsyncEngine):
	"""Remove entries from the old database and add the converted entries to the new database.

	:param old_entries and new_entries: All old entries must be contained in new_entries.
	"""
	async with AsyncSession(new_database) as new_db_session, AsyncSession(old_database) as old_db_session:
		for old_entry in old_entries:
			await old_db_session.delete(old_entry)
		await old_db_session.flush()

		token_entries = [e.token for e in converted_entries]
		new_db_session.add_all(token_entries)

		await new_db_session.flush()
		for entry in converted_entries:
			entry.price_below_notification.token_id = entry.token.token_id

		price_below_notification_entries = [e.price_below_notification for e in converted_entries]
		new_db_session.add_all(price_below_notification_entries)
		new_db_session.flush()

		await new_db_session.commit()
		await old_db_session.commit()

		logger.info(f"Transfered {len(token_entries)} token entry/entries " \
					f"and {len(price_below_notification_entries)} price below notification entries.")


async def main():
	config = configurator.get_config()
	configurator.configure_loguru(TRANSFER_DATABASE_SERVICE_NAME, config)
	if config.paths.old_database is None:
		logger.error("No old backend configured in the config file.")
		sys.exit(1)

	new_database = get_awattprice_engine(config, async_=True)
	old_database = get_engine(config.paths.old_database, async_=True)

	old_entries = await get_old_entries(old_database)
	if len(old_entries) == 0:
		logger.info("No entries from the old database to transfer.")
		sys.exit(0)

	converted_entries = convert_to_new_entries(old_entries)

	await transfer_entries(old_entries, old_database, converted_entries, new_database)


if __name__ == '__main__':
	asyncio.run(main())