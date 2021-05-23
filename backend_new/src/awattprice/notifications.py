"""Manage apple push notifications."""
from enum import auto, Enum
from typing import Union

from box import Box
from fastapi import HTTPException, Request
from loguru import logger
from pydantic import BaseModel
from sqlalchemy import exc as sqlalchemy_exc
from sqlalchemy.ext.asyncio import AsyncSession

from awattprice import defaults, orm, utils
from awattprice.api import db_engine
from awattprice.defaults import Region


class NotificationTask(Enum):
    add_token = auto()


async def add_new_token(token, data):
    """Add a new token to the database."""
    new_token = orm.Token(
        token=token,
        region=data.region,
        tax=data.tax,
    )

    async with AsyncSession(db_engine) as session:
        session.add(new_token)
        try:
            await session.commit()
        except sqlalchemy_exc.IntegrityError as exc:
            logger.warning(f"Tried to add token altough it already existed: {exc}.")
            await session.rollback()
            # This gives information if or if not a token exists in the database which isn't ideal but
            # can't really be avoided.
            raise HTTPException(400)


async def run_notification_tasks(tasks_container: Box):
    """Runs notification configuration tasks."""
    token = tasks_container.token
    tasks = tasks_container.tasks

    # If included add token tasks are always at the beginning.
    first_task = tasks[0]
    if first_task.type == NotificationTask.add_token:
        await add_new_token(token, first_task.payload)


def transform_tasks_body(body: Box):
    """Get a transformed body to get a list of tasks which is more useful for later processing.

    For example at certain points transform strings to enum attributes.
    This also validates that the body matches the correct schema.
    """
    # Boxing again creates a copy rather than referencing to the original instance.
    new_body = Box(body)

    schema = defaults.NOTIFICATION_TASKS_BODY_SCHEMA
    utils.http_exc_validate_json_schema(new_body, schema)

    task_type_counter = Box({NotificationTask.add_token: 0})
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

        task_type_counter[task.type] += 1

    add_token_type_count = task_type_counter[NotificationTask.add_token]
    if add_token_type_count > 1:
        logger.warning(f"Sent more than one add token notification task: {add_token_type_count}.")
        raise HTTPException(400)

    return new_body