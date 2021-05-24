"""Manage apple push notifications."""
from enum import auto
from enum import Enum
from typing import Union

from box import Box
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


class NotificationTask(Enum):
    add_token = auto()
    subscribe_desubscribe = auto()


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


async def run_notification_tasks(tasks_container: Box):
    """Runs notification configuration tasks."""
    token_hex = tasks_container.token
    tasks = tasks_container.tasks

    token = None

    first_task = tasks[0]
    if first_task.type == NotificationTask.add_token:
        token = await add_new_token(token_hex, first_task.payload)
    else:
        token = await get_token(token_hex)


def transform_tasks_body(body: Box):
    """Get a transformed body to get a list of tasks which is more useful for later processing.

    For example at certain points transform strings to enum attributes.
    This also validates that the body matches the correct schema.
    """
    # Boxing again creates a copy rather than referencing to the original instance.
    new_body = Box(body)

    schema = defaults.NOTIFICATION_TASKS_BODY_SCHEMA
    utils.http_exc_validate_json_schema(new_body, schema)

    task_type_counter = Box()
    for index, task in enumerate(new_body.tasks):
        new_type = utils.http_exc_get_enum_attr(NotificationTask, task.type)
        task.type = new_type

        if task.type == NotificationTask.add_token:
            if index != 0:
                logger.warning(f"Add token task is not the first in the task list: {index}.")
                raise HTTPException(400)
            add_token_schema = defaults.NOTIFICATION_TASK_ADD_TOKEN_SCHEMA
            utils.http_exc_validate_json_schema(task.payload, add_token_schema)
            new_region = utils.http_exc_get_enum_attr(Region, task.payload.region)
            task.payload.region = new_region

        if task.type in task_type_counter:
            task_type_counter[task.type] += 1
        else:
            task_type_counter[task.type] = 1

    if NotificationTask.add_token in task_type_counter:
        add_token_type_count = task_type_counter[NotificationTask.add_token]
        if add_token_type_count > 1:
            logger.warning(f"Sent more than one add token notification task: {add_token_type_count}.")
            raise HTTPException(400)

    return new_body