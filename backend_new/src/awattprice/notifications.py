"""Manage apple push notifications."""
from enum import auto, Enum

import jsonschema

from fastapi import HTTPException
from pydantic import BaseModel, ValidationError

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


def get_notifi_tasks(body_json: dict):
    """Validate and get the notification tasks from the request json body."""
