"""Handles interaction between this backend's code and the new backend's code.
Purpose of the interaction is to ensure backwards compatibility between both.
"""

import sys

from awattprice import configurator as v2_configurator # importing from v2 version
from awattprice import database as v2_database # importing from v2 version
from awattprice.orm import PriceBelowNotification # importing from v2 version
from awattprice.orm import Token # importing from v2 version
from loguru import logger as log
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.orm import Session

from .defaults import Region
from .types import APNSToken

v2_config = v2_configurator.get_config()
try:
	v2_database_engine = v2_database.get_awattprice_engine(v2_config, async_=False)
except FileNotFoundError as exc:
	log.error(exc)
	sys.exit(1)


def handle_new_apns_data(request_data: APNSToken):
	"""Handles new apns data of a user which needs to be saved in the v2 database."""
	with Session(v2_database_engine) as session:
		raw_data = session.execute(
			select(Token)
				.where(Token.token == request_data.token)
				.options(selectinload(Token.price_below))
		)
		matching_token = raw_data.scalars().one_or_none()

		request_data_region = Region(request_data.region_identifier).to_v2_region()
		request_data_vat = bool(request_data.vat_selection)
		price_below_notification_active = request_data.config["price_below_value_notification"]["active"]
		price_below_notification_below_value = request_data.config["price_below_value_notification"]["below_value"]

		if matching_token:
			log.debug("Updating token config in v2 database.")
			matching_token.region = request_data_region
			matching_token.tax = request_data_vat

			if matching_token.price_below:
				log.debug("Updating price below notification config in v2 database.")
				matching_token.price_below.active = price_below_notification_active
				matching_token.price_below.below_value = price_below_notification_below_value
		else:
			log.debug("Creating new token entry in v2 database.")
			new_token = Token(token=request_data.token, region=request_data_region, tax=request_data_vat)
			session.add(new_token)

		if not matching_token or not matching_token.price_below:
			if not matching_token:
				session.flush()
				token_id = new_token.token_id
			else:
				token_id = matching_token.token_id

			log.debug("Creating new price below notification entry in v2 database.")
			new_price_below_notification = PriceBelowNotification(token_id=token_id, active=price_below_notification_active, below_value=price_below_notification_below_value)
			session.add(new_price_below_notification)

		session.commit()