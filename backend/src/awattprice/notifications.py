"""Functions to read and save notification configs sent by users.

Sending the actual notifications is handled by an extra service outside of this web app.
"""
from collections import namedtuple
from typing import Any
from typing import Optional

import jsonschema
import sqlalchemy

from box import Box
from box import BoxList
from fastapi import HTTPException
from loguru import logger
from sqlalchemy import inspect
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from awattprice import defaults
from awattprice import utils
from awattprice.defaults import NotificationType
from awattprice.defaults import Region
from awattprice.defaults import TaskType
from awattprice.defaults import UpdateSubject
from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token


async def get_complete_token(session: AsyncSession, token_hex: str) -> Optional[Token]:
    """Get the token orm object with all loaded relationships."""
    stmt = select(Token).where(Token.token == token_hex).options(selectinload(Token.price_below))

    try:
        token_raw = await session.execute(stmt)
        token = token_raw.scalar_one()
    except sqlalchemy.exc.NoResultFound as exc:
        logger.debug(f"No token record for token '{token_hex}' yet.")
        return None

    return token


async def save_notification_configuration(db_engine: AsyncEngine, configuration: Box):
    """Save the notification configuration for a certain token."""
    async with AsyncSession(db_engine, future=True) as session:
        token = await get_complete_token(session, configuration.token)

        if token:
            token.region = configuration.general.region
            token.tax = configuration.general.tax

            if token.price_below:
                token.price_below.active = configuration.notifications.price_below.active
                token.price_below.below_value = configuration.notifications.price_below.below_value
        else:
            new_token = Token(
                token=configuration.token, region=configuration.general.region, tax=configuration.general.tax
            )
            session.add(new_token)

        if not token or not token.price_below:
            if not token:
                new_token.flush()
                token_id = new_token.token_id
            else:
                token_id = token.token_id

            new_price_below_notification = PriceBelowNotification(
                active=configuration.notifications.price_below.active,
                below_value=configuration.notifications.price_below.below_value,
            )
            session.add(new_price_below_notification)

        await session.commit()


def parse_notification_configuration_body(configuration: Box) -> Optional[Box]:
    """Validates and parses the notification configuration into an internal format.

    :returns: None if configuration couldn't be parsed, otherwise return the configuration in internal format.
    """
    schema = defaults.NOTIFICATION_CONFIGURATION_SCHEMA
    try:
        jsonschema.validate(configuration, schema)
    except jsonschema.ValidationError as exc:
        logger.warning(f"Clients tasks json is not valid: {exc}.")
        return None

    configuration.general.region = Region[configuration.general.region]

    return configuration
