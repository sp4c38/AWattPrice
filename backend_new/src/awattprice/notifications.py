"""Manage apple push notifications."""
from typing import Union

import sqlalchemy

from box import Box
from box import BoxList
from fastapi import HTTPException
from fastapi import Request
from loguru import logger
from pydantic import BaseModel
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


async def add_new_token(session: AsyncSession, token_hex: str, data: dict) -> Token:
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
        logger.warning(f"Tried to add token altough it already existed: {exc}.")
        await session.rollback()
        raise HTTPException(400)

    return new_token


async def get_token(session: AsyncSession, token_hex: str) -> Token:
    """Get a orm token object from the tokens hex identifier."""
    stmt = select(Token).where(Token.token == token_hex)
    try:
        token_raw = await session.execute(stmt)
        token = token_raw.scalar_one()
    except sqlalchemy.exc.NoResultFound as exc:
        logger.warning(f"No token found for a token: {exc}.")
        raise HTTPException(400)
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
        if sub_else_desub is True:
            logger.debug("Resubscribing to price below notification.")
            notification.active = True
        else:
            logger.debug("Desubscribing from price below notification.")
            notification.active = False

    await session.commit()


async def run_notification_tasks(tasks_container: Box):
    """Runs notification configuration tasks."""
    token_hex = tasks_container.token
    token = None
    tasks = tasks_container.tasks

    session = AsyncSession(db_engine, expire_on_commit=False, future=True)

    first_task = tasks[0]
    if first_task.type == TaskType.add_token:
        token = await add_new_token(session, token_hex, first_task.payload)
        tasks.pop(0)
    else:
        token = await get_token(session, token_hex)
    for task in tasks:
        logger.debug(task)
        if task.type == TaskType.subscribe_desubscribe:
            if task.payload.notification_type == NotificationType.price_below:
                await sub_desub_price_below(session, token, task.payload)

    await session.close()


def check_modify_task(task_index: int, task: Box):
    """Check for correct task format and eventually modify the data in the task.

    Also change some values to use enums, ... instead of representing as strings or similar.
    """
    if task.type == TaskType.add_token:
        if task_index != 0:
            logger.warning(f"Add token task is not the first in the task list: {task_index}.")
            raise HTTPException(400)
        add_token_schema = defaults.NOTIFICATION_TASK_ADD_TOKEN_SCHEMA
        utils.http_exc_validate_json_schema(task.payload, add_token_schema)
        task.payload.region = Region[task.payload.region]

    elif task.type == TaskType.subscribe_desubscribe:
        sub_desub_schema = defaults.NOTIFICATION_TASK_SUB_DESUB_SCHEMA
        utils.http_exc_validate_json_schema(task.payload, sub_desub_schema)
        task.payload.notification_type = NotificationType[task.payload.notification_type]

        if task.payload.notification_type == NotificationType.price_below:
            price_below_schema = defaults.NOTIFICATION_TASK_PRICE_BELOW_SUB_DESUB_SCHEMA
            utils.http_exc_validate_json_schema(task.payload.notification_info, price_below_schema)

    elif task.type == TaskType.update:
        update_schema = defaults.NOTIFICATION_TASK_UPDATE_SCHEMA
        utils.http_exc_validate_json_schema(task.payload, update_schema)
        task.payload.subject = UpdateSubject[task.payload.subject]

        updated_data = task.payload.updated_data
        if task.payload.subject == UpdateSubject.general:
            general_schema = defaults.NOTIFICATION_TASK_UPDATE_GENERAL_SCHEMA
            utils.http_exc_validate_json_schema(updated_data, general_schema)
        elif task.payload.subject == UpdateSubject.price_below:
            price_below_schema = defaults.NOTIFICATION_TASK_UPDATE_PRICE_BELOW_SCHEMA
            utils.http_exc_validate_json_schema(updated_data, price_below_schema)
        else:
            logger.warning(
                f"Requested update of '{task.payload.subject}', but schema checking isn't implemented for subject."
            )
            raise HTTPException(501)


def count_task_type(task: Box, type_counter: Box):
    """Count a new task in a task type counter dict."""
    if task.type == TaskType.subscribe_desubscribe:
        notification_type = task.payload.notification_type
        if task.type in type_counter:
            type_counter[task.type][notification_type] += 1
        else:
            type_counter[task.type] = Box()
            type_counter[task.type][notification_type] = 1
    else:
        if task.type in type_counter:
            type_counter[task.type] += 1
        else:
            type_counter[task.type] = 1


def check_task_type_counter(type_counter: Box):
    """Verify that contraints on the amount of different task types are followed."""
    if TaskType.add_token in type_counter:
        if type_counter[TaskType.add_token] > 1:
            logger.warning(f"Sent more than one add token notification task: {add_token_type_count}.")
            raise HTTPException(400)

    if TaskType.subscribe_desubscribe in type_counter:
        for notification_type in type_counter[TaskType.subscribe_desubscribe]:
            notification_type_count = type_counter[TaskType.subscribe_desubscribe][notification_type]
            if notification_type_count > 1:
                logger.warning(
                    f"Sent more than one sub/desub task for notification type {notification_type.name}."
                )
                raise HTTPException(400)


def transform_tasks_body(body: Box):
    """Get a transformed body to get a list of tasks which is more useful for later processing.

    For example at certain points transform strings to enum attributes.
    This also validates that the body matches the correct schema.
    """
    # Boxing again creates a copy rather than referencing to the original instance.
    new_body = Box(body)

    schema = defaults.NOTIFICATION_TASKS_BODY_SCHEMA
    utils.http_exc_validate_json_schema(new_body, schema)

    type_counter = Box()  # Counter to count different task types
    for index, task in enumerate(new_body.tasks):
        # Jsonschema validates that only task types in the enum come to this position.
        new_type = TaskType[task.type]
        task.type = new_type

        check_modify_task(index, task)

        count_task_type(task, type_counter)

    check_task_type_counter(type_counter)

    return new_body
