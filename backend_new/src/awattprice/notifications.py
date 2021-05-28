"""Manage apple push notifications."""
from typing import Union

from box import Box
from box import BoxList
from fastapi import HTTPException
from fastapi import Request
from loguru import logger
from pydantic import BaseModel
from sqlalchemy import exc as sqlalchemy_exc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from awattprice import defaults
from awattprice import utils
from awattprice.api import db_engine
from awattprice.defaults import Region
from awattprice.orm import Token


async def add_new_token(token_hex: str, data: dict) -> Token:
    """Add a new token to the database."""
    new_token = Token(
        token=token_hex,
        region=data.region,
        tax=data.tax,
    )

    async with AsyncSession(db_engine, future=True) as session:
        session.add(new_token)
        try:
            await session.commit()
        except sqlalchemy_exc.IntegrityError as exc:
            logger.warning(f"Tried to add token altough it already existed: {exc}.")
            await session.rollback()
            raise HTTPException(400)

    return new_token


async def get_token(token_hex: str) -> Token:
    async with AsyncSession(db_engine, future=True) as session:
        stmt = select(Token).where(Token.token == token_hex)
        try:
            token_raw = await session.execute(stmt)
            token = token_raw.scalar_one()
        except sqlalchemy_exc.NoResultFound as exc:
            logger.warning(f"No token found for hex '{token_hex}': {exc}.")
            raise HTTPException(400)
        # The MultipleResultsFound exception will never be raised because the token has a unique constraint.

    return token


async def sub_desub_price_below(token: Token, sub_else_desub: bool, data: Box):
    """Subscribe or desubscribe a token to the price below value notification."""
    pass



async def run_notification_tasks(tasks_container: Box):
    """Runs notification configuration tasks."""
    token_hex = tasks_container.token
    tasks = tasks_container.tasks

    token = None
    first_task = tasks[0]
    if first_task.type == defaults.TaskType.add_token:
        token = await add_new_token(token_hex, first_task.payload)
        tasks.pop(0)
    else:
        token = await get_token(token_hex)

    for task in tasks:
        if task.type == defaults.TaskType.subscribe_desubscribe:
            notification_sub_else_desub = task.payload.sub_else_desub
            notification_info = task.payload.notification_info
            if task.payload.notification_type == defaults.NotificationType.price_below:
                await sub_desub_price_below(token, notification_sub_else_desub, notification_info)

        logger.debug(task)


def check_modify_task(task_type: defaults.TaskType, payload: Union[Box, BoxList]):
    """Check for correct task format and eventually modify the data in the task.

    Also change some values to use enums, ... instead of representing as strings or similar.
    """
    if task_type == defaults.TaskType.add_token:
        if index != 0:
            logger.warning(f"Add token task is not the first in the task list: {index}.")
            raise HTTPException(400)
        add_token_schema = defaults.NOTIFICATION_TASK_ADD_TOKEN_SCHEMA
        utils.http_exc_validate_json_schema(task.payload, add_token_schema)
        new_region = utils.http_exc_get_attr(Region, task.payload.region)
        task.payload.region = new_region
    elif task_type == defaults.TaskType.subscribe_desubscribe:
        sub_desub_schema = defaults.NOTIFICATION_TASK_SUB_DESUB_SCHEMA
        utils.http_exc_validate_json_schema(payload, sub_desub_schema)
        new_notification_type = defaults.NotificationType[payload.notification_type]
        new_sub_desub = defaults.SubscribeDesubscribe[payload.sub_desub]
        payload.notification_type = new_notification_type
        payload.sub_desub = new_sub_desub
        if payload.notification_type == defaults.NotificationType.price_below:
            price_below_schema = defaults.NOTIFICATION_TASK_PRICE_BELOW_SUB_DESUB_SCHEMA
            utils.http_exc_validate_json_schema(payload.notification_info, price_below_schema)


def transform_tasks_body(body: Box):
    """Get a transformed body to get a list of tasks which is more useful for later processing.

    For example at certain points transform strings to enum attributes.
    This also validates that the body matches the correct schema.
    """
    # Boxing again creates a copy rather than referencing to the original instance.
    new_body = Box(body)

    schema = defaults.NOTIFICATION_TASKS_BODY_SCHEMA
    utils.http_exc_validate_json_schema(new_body, schema)

    task_type_counter = Box({defaults.TaskType.add_token: 0})
    for index, task in enumerate(new_body.tasks):
        # Jsonschema validates that only task types in the enum come to this position.
        new_type = defaults.TaskType[task.type]
        task.type = new_type

        check_modify_task(task.type, task.payload)

        if task.type in task_type_counter:
            task_type_counter[task.type] += 1

    if defaults.TaskType.add_token in task_type_counter:
        add_token_type_count = task_type_counter[defaults.TaskType.add_token]
        if add_token_type_count > 1:
            logger.warning(f"Sent more than one add token notification task: {add_token_type_count}.")
            raise HTTPException(400)

    return new_body