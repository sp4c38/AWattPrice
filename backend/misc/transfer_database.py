# Transfer token settings and price below notification settings from the old database to the new database.
import asyncio
import json
import sys

from awattprice import configurator
from awattprice.database import get_awattprice_engine
from awattprice.database import get_engine
from box import Box
from sqlalchemy import Column
from sqlalchemy import Integer
from sqlalchemy import MetaData
from sqlalchemy import select
from sqlalchemy import String
from sqlalchemy import Table
from sqlalchemy.ext.asyncio import AsyncEngine

TRANSFER_DATABASE_SERVICE_NAME = "transfer_database"

async def get_old_notification_config(old_database: AsyncEngine) -> list:
	metadata = MetaData()
	notification_config_table = Table("token_storage", metadata,
		Column("token", String, primary_key=True),
		Column("region_identifier", Integer),
		Column("vat_selection", Integer),
		Column("configuration", String)
	)
	request = select(notification_config_table)
	async with old_database.connect() as connection:
		raw_results = await connection.execute(request)

	notification_configs = [Box(dict(x)) for x in raw_results.fetchall()]
	for notification_config in notification_configs:
		try:
			notification_config.configuration = Box(json.loads(notification_config.configuration))
		except json.JSONDecodeError as exc:
			logger.error(f"Old notification config configuration is no valid json: {notification_config.configuration} - {exc}.")
			sys.exit(1)

	return notification_configs


async def main():
	config = configurator.get_config()
	configurator.configure_loguru(TRANSFER_DATABASE_SERVICE_NAME, config)
	if config.paths.old_database is None:
		logger.error("No old backend configured in the config file.")
		sys.exit(1)

	new_database = get_awattprice_engine(config, async_=True)
	old_database = get_engine(config.paths.old_database, async_=True)

	old_notification_config = await get_old_notification_config(old_database)
	print(old_notification_config)


if __name__ == '__main__':
	asyncio.run(main())