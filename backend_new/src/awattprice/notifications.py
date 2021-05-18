"""Manage apple push notifications."""
from pydantic import BaseModel


class NewNotification(BaseModel):
    """The payload submitted by the client when registering a new notification."""

    token: str


def register_new_token():
    """Register a new push notification token."""
    pass
