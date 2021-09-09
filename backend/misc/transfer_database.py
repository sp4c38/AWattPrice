# Transfer token settings and price below notification settings from the old database to the new database.
import asyncio
import json
import sys

from awattprice import configurator
from awattprice.database import get_awattprice_engine
from awattprice.database import get_engine
from awattprice.defaults import Region
from awattprice.orm import Token
from awattprice.orm import PriceBelowNotification
from box import Box
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


async def get_old_notification_configs(old_database: AsyncEngine) -> list:
	async with AsyncSession(old_database) as session:
		raw_results = await session.execute(select(OldTokenStorage))

	notification_configs = raw_results.scalars().all()
	for notification_config in notification_configs:
		if notification_config is None:
			logger.error("Couldn't get notification configuration.")
			sys.exit(1)

	return notification_configs

def convert_to_entries(old_notification_configs: list[Box]) -> Box:
	"""Convert the entries of the old database to table row entries for the new database."""
	new_entries = Box(token=[], price_below_notification=[])
	for notification_config in old_notification_configs:
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
		new_entries.token.append(new_token)
		new_entries.price_below_notification.append(new_price_below_notification)

	return new_entries

async def main():
	config = configurator.get_config()
	configurator.configure_loguru(TRANSFER_DATABASE_SERVICE_NAME, config)
	if config.paths.old_database is None:
		logger.error("No old backend configured in the config file.")
		sys.exit(1)

	new_database = get_awattprice_engine(config, async_=True)
	old_database = get_engine(config.paths.old_database, async_=True)

	old_notification_configs = await get_old_notification_configs(old_database)
	print(convert_to_entries(old_notification_configs))



if __name__ == '__main__':
	asyncio.run(main())