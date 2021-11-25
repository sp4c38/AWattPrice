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

from awattprice import defaults
from awattprice import utils
from awattprice.defaults import NotificationType
from awattprice.defaults import Region
from awattprice.defaults import TaskType
from awattprice.defaults import UpdateSubject
from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token


async def get_token(session: AsyncSession, token_hex: str) -> Token:
    """Get a orm token object using the token's hex identifier."""
    stmt = select(Token).where(Token.token == token_hex)
    try:
        token_raw = await session.execute(stmt)
        token = token_raw.scalar_one()
    except sqlalchemy.exc.NoResultFound as exc:
        logger.warning(f"No token record found for token '{token_hex}': {exc}.")
        await session.rollback()
        raise HTTPException(400) from exc
    # The MultipleResultsFound exception will never be raised because the token has a unique constraint.

    return token


async def add_new_token(session: AsyncSession, token_hex: str, configuration: Box) -> Token:
    """Save a new token to the database and return the new orm object.

    :param extra_values: Extra values for the new token. These include region and tax selection.
    """
    token = Token(
        token=token_hex,
        region=configuration.region,
        tax=configuration.tax,
    )
    session.add(token)

    try:
        await session.commit()
    except sqlalchemy.exc.IntegrityError as exc:
        await session.rollback()
        logger.warning(f"Tried to add token although it already existed: {exc}.")
        token = await get_token(session, token_hex)
        token.region = configuration.region
        token.tax = configuration.tax
        return token

    await session.refresh(token, attribute_names=["token_id"])

    return token


async def sub_desub_price_below(session: AsyncSession, token: Token, payload: Box):
    """Subscribe or desubscribe a token to the price below value notification."""
    stmt = select(PriceBelowNotification).where(PriceBelowNotification.token_id == token.token_id)
    notification_results = await session.execute(stmt)
    notification = notification_results.scalar_one_or_none()

    notification_active = payload.active
    notification_info = payload.notification_info
    if notification is None:
        if notification_active is True:
            logger.debug("Subscribing to price below notification.")
            new_price_below_notification = PriceBelowNotification(
                token_id=token.token_id,
                active=True,
                below_value=notification_info.below_value,
            )
            session.add(new_price_below_notification)
    else:
        if notification_active is True and notification.active is False:
            logger.debug("Resubscribing to price below notification.")
            notification.active = True
        elif notification_active is False and notification.active is True:
            logger.debug("Desubscribing from price below notification.")
            notification.active = False
        else:
            logger.info(
                f"Current notification active state ({notification.active}) is "
                f"already set to new state: {notification_active}."
            )


async def update_general_settings(session: AsyncSession, token: Token, updated_data: Box):
    """Update general notification settings for a certain token."""
    logger.debug("Updating general notification settings for a token.")
    for key, new_value in updated_data.items():  # .items() -> [(key, value), ...]
        if key == "region":
            token.region = new_value
            logger.debug(f"Updated region to '{new_value}'.")
        elif key == "tax":
            token.tax = new_value
            logger.debug(f"Updated tax to '{new_value}'.")
        else:
            logger.critical(f"Don't know how to update '{key}' key.")
            await session.rollback()
            raise HTTPException(501)


async def update_price_below_settings(session: AsyncSession, token: Token, updated_data: Box):
    """Update price below notification settings for a certain token."""
    logger.debug("Updating price below notification settings for a token.")
    price_below = None
    token_inspector = inspect(token)
    if "price_below" in token_inspector.unloaded:
        stmt = select(PriceBelowNotification).where(PriceBelowNotification.token == token)
        price_below_results = await session.execute(stmt)
        price_below = price_below_results.scalar_one_or_none()
    else:
        price_below = token.price_below

    if price_below is None:
        logger.warning("Can't update settings because no price below entry exists yet.")
        await session.rollback()
        raise HTTPException(409)
    if price_below.active is False:
        logger.warning("Can't update settings because price below notification is inactive.")
        await session.rollback()
        raise HTTPException(409)

    for key, new_value in updated_data.items():
        if key == "below_value":
            price_below.below_value = new_value
            logger.debug(f"Updated below value to '{new_value}'.")
        else:
            logger.critical(f"Don't know how to update '{key}' key.")
            await session.rollback()
            raise HTTPException(501)


async def run_notification_tasks(db_engine: AsyncEngine, token_hex: str, tasks: BoxList):
    """Run multiple notification tasks."""
    async with AsyncSession(db_engine, future=True) as session:
        first_task = tasks[0]
        if first_task.type == TaskType.ADD_TOKEN:
            token = await add_new_token(session, token_hex, first_task.payload)
            tasks.pop(0)
        else:
            token = await get_token(session, token_hex)

        for task in tasks:
            if task.type == TaskType.SUBSCRIBE_DESUBSCRIBE:
                if task.payload.notification_type == NotificationType.PRICE_BELOW:
                    await sub_desub_price_below(session, token, task.payload)
            elif task.type == TaskType.UPDATE:
                if task.payload.subject == UpdateSubject.GENERAL:
                    await update_general_settings(session, token, task.payload.updated_data)
                elif task.payload.subject == UpdateSubject.PRICE_BELOW:
                    await update_price_below_settings(session, token, task.payload.updated_data)

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
