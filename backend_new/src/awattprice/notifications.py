"""Manage apple push notifications."""
from enum import auto, Enum

import jsonschema

from box import Box
from fastapi import HTTPException, Request
from pydantic import BaseModel

from awattprice import defaults
from awattprice.defaults import Region


class RegisterNewTokenPayload(BaseModel):
    token: str
    region: Region
    tax: bool


async def add_new_token(data: Box):
    pass


class NotificationTask(Enum):
    register_new_token = auto()


async def run_notifi_tasks(tasks: dict):
    """Runs tasks for a token regarding notification configuration."""
    for task in tasks:
        task_type = getattr(APNsTask, task.type)
        if task_type == APNsTask.register_new_token:
            await add_new_token(task.payload)

def get_body_tasks(body: Box):
    """Get the tasks out of the json body of the request.

    This also validates the json body to match the correct scheme.
    """
    schema = defaults.NOTIFICATION_TASKS_BODY_SCHEMA
    try:
        jsonschema.validate(body, schema)
    except jsonschema.ValidationError as exp:
        raise HTTPException(400, "Body doesn't match correct schema.") from exp
