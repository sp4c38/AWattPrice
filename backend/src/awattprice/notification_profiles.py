"""JSON-backed storage and validation for notification profiles."""
from __future__ import annotations

import json
import os

from datetime import datetime
from datetime import UTC
from decimal import Decimal
from pathlib import Path
from typing import Any
from typing import Optional

import jsonschema

from box import Box
from filelock import FileLock
from loguru import logger

from awattprice import defaults

SCHEMA_VERSION = 1
STORE_FILE_NAME = "notification-profiles.json"
DEFAULT_ADD_ON_ORDER = ["tax", "percentage", "fixed", "monthly"]


def get_store_path(config) -> Path:
    """Return the configured notification profile store path."""
    return config.paths.data_dir / STORE_FILE_NAME


def _decimal_from_number(value: Any) -> Decimal:
    return Decimal(str(value))


def normalize_add_on_order(order: list[str] | None) -> list[str]:
    """Return an add-on order with the tax step in the legacy-compatible position."""
    result = []
    if order is None or "tax" not in order:
        result.append("tax")
    for add_on in order or DEFAULT_ADD_ON_ORDER:
        if add_on not in result:
            result.append(add_on)
    for add_on in DEFAULT_ADD_ON_ORDER:
        if add_on not in result:
            result.append(add_on)
    return result


def parse_notification_profile_body(profile: Box) -> Optional[Box]:
    """Validate and normalize a notification profile request body."""
    if "general" in profile and "area" in profile.general:
        profile.general.area = defaults.normalize_market_area_key(profile.general.area)

    try:
        jsonschema.validate(profile, defaults.NOTIFICATION_PROFILE_SCHEMA)
    except jsonschema.ValidationError as exc:
        logger.warning(f"Notification profile json is not valid: {exc}.")
        return None

    profile.general.base_fee = _decimal_from_number(profile.general.base_fee)
    profile.general.percentage_add_on = _decimal_from_number(profile.general.percentage_add_on)
    if "fixed_add_on" not in profile.general:
        profile.general.fixed_add_on = profile.general.base_fee
    else:
        profile.general.fixed_add_on = _decimal_from_number(profile.general.fixed_add_on)
    if "monthly_fixed_cost_add_on" not in profile.general:
        profile.general.monthly_fixed_cost_add_on = Decimal("0")
    else:
        profile.general.monthly_fixed_cost_add_on = _decimal_from_number(profile.general.monthly_fixed_cost_add_on)
    if "add_on_order" not in profile.general:
        profile.general.add_on_order = DEFAULT_ADD_ON_ORDER
    else:
        profile.general.add_on_order = normalize_add_on_order(profile.general.add_on_order)

    for rule_name in ("price_below", "price_above"):
        rule = profile.rules[rule_name]
        if "threshold" not in rule:
            rule.threshold = None
        if rule.active is True and rule.threshold is None:
            logger.warning(f"Notification rule {rule_name} is active but has no threshold.")
            return None

    return profile


class NotificationProfileStore:
    """Small JSON document store for notification profiles."""

    def __init__(self, path: Path):
        self.path = path
        self.lock = FileLock(str(path) + ".lock")

    def load(self) -> dict[str, Any]:
        """Load the complete store document."""
        with self.lock:
            return self._load_unlocked()

    def list_profiles(self) -> list[Box]:
        """Return all profiles from the store as Boxes."""
        document = self.load()
        return [self._normalize_stored_profile(Box(profile)) for profile in document["profiles"].values()]

    def save_profile(self, profile: Box) -> None:
        """Replace a single token profile in the JSON store."""
        with self.lock:
            document = self._load_unlocked()
            stored_profile = profile.to_dict()
            stored_profile["updated_at"] = datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
            document["profiles"][profile.token] = stored_profile
            self._write_unlocked(document)

    def delete_profile(self, token: str) -> None:
        """Delete one token profile if it exists."""
        with self.lock:
            document = self._load_unlocked()
            document["profiles"].pop(token, None)
            self._write_unlocked(document)

    def _load_unlocked(self) -> dict[str, Any]:
        if not self.path.exists():
            return self._empty_document()

        try:
            with self.path.open("r", encoding="utf-8") as file:
                document = json.load(file)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Notification profile store is not valid JSON: {self.path}") from exc

        if document.get("schema_version") != SCHEMA_VERSION:
            raise ValueError(f"Unsupported notification profile schema version in {self.path}.")

        if not isinstance(document.get("profiles"), dict):
            raise ValueError(f"Notification profile store has no profiles object: {self.path}.")

        return document

    def _write_unlocked(self, document: dict[str, Any]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = self.path.with_suffix(self.path.suffix + ".tmp")
        with temporary_path.open("w", encoding="utf-8") as file:
            json.dump(document, file, indent=2, sort_keys=True, default=str)
            file.write("\n")
        os.replace(temporary_path, self.path)

    @staticmethod
    def _empty_document() -> dict[str, Any]:
        return {"schema_version": SCHEMA_VERSION, "profiles": {}}

    @staticmethod
    def _normalize_stored_profile(profile: Box) -> Box:
        profile.general.base_fee = Decimal(str(profile.general.base_fee))
        profile.general.percentage_add_on = Decimal(str(profile.general.percentage_add_on))
        if "fixed_add_on" not in profile.general:
            profile.general.fixed_add_on = profile.general.base_fee
        else:
            profile.general.fixed_add_on = Decimal(str(profile.general.fixed_add_on))
        if "monthly_fixed_cost_add_on" not in profile.general:
            profile.general.monthly_fixed_cost_add_on = Decimal("0")
        else:
            profile.general.monthly_fixed_cost_add_on = Decimal(str(profile.general.monthly_fixed_cost_add_on))
        if "add_on_order" not in profile.general:
            profile.general.add_on_order = DEFAULT_ADD_ON_ORDER
        else:
            profile.general.add_on_order = NotificationProfileStore._normalize_add_on_order(profile.general.add_on_order)
        return profile

    @staticmethod
    def _normalize_add_on_order(order: list[str]) -> list[str]:
        return normalize_add_on_order(order)
