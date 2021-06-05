"""Functions to read and save notification configs sent by users.

Sending the actual notifications is handled by an extra service outside of this web app.
"""
from dataclasses import dataclass
from typing import Any
from typing import Optional

import sqlalchemy

from box import Box
from box import BoxList
from fastapi import HTTPException
from loguru import logger
from sqlalchemy import inspect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from awattprice import defaults
from awattprice import utils
from awattprice.api import db_engine
from awattprice.defaults import NotificationType
from awattprice.defaults import Region
from awattprice.defaults import TaskType
from awattprice.defaults import UpdateSubject
from awattprice.orm import PriceBelowNotification
from awattprice.orm import Token


async def add_new_token(session: AsyncSession, token_hex: str, data: Box) -> Token:
    """Construct a new token and add it to the database."""
    new_token = Token(
        token=token_hex,
        region=data.region,
        tax=data.tax,
    )

    session.add(new_token)
    try:
        await session.commit()
    except sqlalchemy.exc.IntegrityError as exc:
        logger.warning(f"Tried to add token although it already existed: {exc}.")
        await session.rollback()
        raise HTTPException(400) from exc

    return new_token


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


async def sub_desub_price_below(session: AsyncSession, token: Token, payload: Box):
    """Subscribe or desubscribe a token to the price below value notification."""
    stmt = select(PriceBelowNotification)  # .where(PriceBelowNotification.token_id == token.token_id)
    notification_results = await session.execute(stmt)
    notification = notification_results.scalar_one_or_none()

    sub_else_desub = payload.sub_else_desub
    below_value = payload.notification_info.below_value
    if notification is None:
        if sub_else_desub is True:
            logger.info("Subscribing to price below notification.")
            new_price_below_notification = PriceBelowNotification(
                token_id=token.token_id,
                active=True,
                below_value=below_value,
            )
            session.add(new_price_below_notification)
    else:
        if sub_else_desub is True and notification.active is not True:
            logger.debug("Resubscribing to price below notification.")
            notification.active = True
        elif sub_else_desub is False and notification.active is not False:
            logger.debug("Desubscribing from price below notification.")
            notification.active = False
        else:
            logger.info(
                f"Current 'sub-else-desub' state ({notification.active}) is "
                f"already set to new state: {sub_else_desub}."
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


async def run_notification_tasks(tasks_container: Box):
    """Runs notification configuration tasks."""
    async with AsyncSession(db_engine, future=True) as session:
        tasks = tasks_container.tasks

        token = None
        token_hex = tasks_container.token
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
                else:
                    logger.critical(f"Don't know how to update subject {task.payload.subject}.")
                    await session.rollback()
                    raise HTTPException(501)
            else:
                logger.critical(f"Don't know how to process notification task type {task.type}.")
                await session.rollback()
                raise HTTPException(501)

        await session.commit()


def transform_add_token_task(task: Box, task_index: int):
    """Check for correct 'add token' task schema and transform the task."""
    if task_index != 0:
        logger.warning(f"Add token task is not the first in the task list: {task_index}.")
        raise HTTPException(400)

    add_token_schema = defaults.NOTIFICATION_TASK_ADD_TOKEN_SCHEMA
    utils.http_exc_validate_json_schema(task.payload, add_token_schema, http_code=400)

    task.payload.region = Region[task.payload.region]


def transform_subscribe_desubscribe_task(task: Box):
    """Check for correct 'subscribe_desubscribe' task schema and transform the task."""
    sub_desub_schema = defaults.NOTIFICATION_TASK_SUB_DESUB_SCHEMA
    utils.http_exc_validate_json_schema(task.payload, sub_desub_schema, http_code=400)

    task.payload.notification_type = NotificationType[task.payload.notification_type]

    notification_info = task.payload.notification_info
    if task.payload.notification_type == NotificationType.PRICE_BELOW:
        price_below_schema = defaults.NOTIFICATION_TASK_PRICE_BELOW_SUB_DESUB_SCHEMA
        utils.http_exc_validate_json_schema(notification_info, price_below_schema, http_code=400)


def transform_update_task(task: Box):
    """Check for correct 'update' task schema and transform the task."""
    update_schema = defaults.NOTIFICATION_TASK_UPDATE_SCHEMA
    utils.http_exc_validate_json_schema(task.payload, update_schema, http_code=400)

    task.payload.subject = UpdateSubject[task.payload.subject]

    updated_data = task.payload.updated_data
    if task.payload.subject == UpdateSubject.GENERAL:
        general_schema = defaults.NOTIFICATION_TASK_UPDATE_GENERAL_SCHEMA
        utils.http_exc_validate_json_schema(updated_data, general_schema, http_code=400)
    elif task.payload.subject == UpdateSubject.PRICE_BELOW:
        price_below_schema = defaults.NOTIFICATION_TASK_UPDATE_PRICE_BELOW_SCHEMA
        utils.http_exc_validate_json_schema(updated_data, price_below_schema, http_code=400)
    else:
        logger.critical(f"Subject '{task.payload.subject}' task validation isn't implemented.")
        raise HTTPException(501)


@dataclass(eq=True, frozen=True)
class StitchedTaskTypes:
    """Store notification task type and task sub-types together as a stitched version.

    This class is immutable. Thus it can be used as keys in a dictionary.
    """

    task_type: TaskType
    sub_types: Optional[tuple[Any]] = None


def check_type_count(tasks: BoxList) -> bool:
    """Verify number of certain task types match allowed amount."""
    stitched_types_counted = Box()
    for task in tasks:
        if task.type == TaskType.SUBSCRIBE_DESUBSCRIBE:
            stitched_types = StitchedTaskTypes(task.type, (task.payload.notification_type,))
        elif task.type == TaskType.UPDATE:
            stitched_types = StitchedTaskTypes(task.type, (task.payload.subject,))
        else:
            stitched_types = StitchedTaskTypes(task.type)

        # Sometimes when counting tasks, restrictions on the amount of the task is not depending only on the
        # task type but additionally also on some types inside of the task payload, thus using stitched types.
        stitched_types_counted[stitched_types] = stitched_types_counted.get(stitched_types, 0) + 1

    for stitched_types, count in stitched_types_counted.items():
        if any(
            (
                stitched_types.task_type == TaskType.ADD_TOKEN,
                # Only allow one sub/desub task for each different notification type. So multiple sub/desubs
                # are allowed, but only one per notification type.
                stitched_types.task_type == TaskType.SUBSCRIBE_DESUBSCRIBE,
                stitched_types.task_type == TaskType.UPDATE,
            )
        ):
            if count > 1:
                logger.warning(f"More than one stitched task: {stitched_types}.")
                return False

    return True


def transform_tasks_body(body_original: Box) -> Box:
    """Transform the body with notification tasks to perform.

    First validates correct schema of body. Then transforms to make body more clearer to improve
    the beauty of the code. For example transform to enums instead of using raw strings.
    """
    body = Box(body_original)  # Box again to create new instance instead of reference.

    # Validate base schema of body.
    schema = defaults.NOTIFICATION_TASKS_BODY_SCHEMA
    utils.http_exc_validate_json_schema(body, schema, http_code=400)

    # Validate task-specific schemas.
    for index, task in enumerate(body.tasks):
        task.type = TaskType[task.type]

        if task.type == TaskType.ADD_TOKEN:
            transform_add_token_task(task, index)
        elif task.type == TaskType.SUBSCRIBE_DESUBSCRIBE:
            transform_subscribe_desubscribe_task(task)
        elif task.type == TaskType.UPDATE:
            transform_update_task(task)

    check_type_count(body.tasks)

    return body
