"""Manage apple push notifications."""
from enum import auto, Enum
from typing import Union

from box import Box
from fastapi import HTTPException, Request
from loguru import logger
from pydantic import BaseModel

from awattprice import defaults, utils
from awattprice.defaults import Region


async def run_notification_tasks(tasks_container: Box):
    """Runs notification configuration tasks."""
    token = tasks_container.token
    tasks = tasks_container.tasks


class NotificationTask(Enum):
    add_token = auto()


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
    for task in new_body.tasks:
        new_type = utils.http_exc_get_enum_attr(NotificationTask, task.type)
        task.type = new_type

        if task.type == NotificationTask.add_token:
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