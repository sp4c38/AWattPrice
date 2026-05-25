"""Manage and handle price data from the main awattprice package."""
import asyncio
import os
import pickle

from typing import Optional

from aiofile import async_open
from arrow import Arrow
from awattprice import prices as awattprice_prices
from box import Box
from liteconfig import Config
from loguru import logger

from awattprice_notifications import rules
from awattprice_notifications.rules import check_area_updated
from awattprice_notifications.rules import get_notifiable_prices


class NotifiablePriceData:
    """Holds prices that may trigger user notifications."""

    data: Box

    def __init__(self, data: Box):
        self.data = data


async def collect_areas_prices(config: Config, area_keys: list[str]) -> Box:
    """Get the current prices for multiple market areas."""
    prices_tasks = [awattprice_prices.get_stored_data(area_key, config) for area_key in area_keys]
    areas_prices = await asyncio.gather(*prices_tasks)
    areas_prices = dict(zip(area_keys, areas_prices))

    existing_areas_prices = {}
    for area_key, prices in areas_prices.items():
        if prices is None:
            continue
        existing_areas_prices[area_key] = prices

    return existing_areas_prices


async def read_last_updated_endtime(config: Config, area_key: str) -> Optional[Arrow]:
    """Get the end time of the latest price point when the price data was updated last for the certain area."""
    file_name = rules.LAST_UPDATED_ENDTIME_FILE_NAME.format(area_key.lower())
    file_path = config.paths.price_data_dir / file_name
    try:
        async with async_open(file_path, "rb") as file:
            pickled_time = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No last updated endtime for area {area_key} exists yet: {exc}.")
        return None

    time = pickle.loads(pickled_time)
    return time


def get_current_endtime(prices: Box) -> Arrow:
    latest_price_point = max(prices.prices, key=lambda price_point: price_point.end_timestamp)
    current_endtime = latest_price_point.end_timestamp
    return current_endtime


async def get_updated_areas(config: Config, areas_prices: Box[str, Box]) -> list[str]:
    """Get the areas of which their prices updated relative to the last time they updated."""
    area_keys = areas_prices.keys()
    prices = areas_prices.values()

    endtimes_tasks = [read_last_updated_endtime(config, area_key) for area_key in area_keys]
    endtimes = await asyncio.gather(*endtimes_tasks, return_exceptions=True)

    updated_areas = []
    areas_prices_endtimes = list(zip(area_keys, prices, endtimes))
    for area_key, prices, stored_endtime in areas_prices_endtimes:
        if isinstance(stored_endtime, Exception):
            logger.exception(f"Couldn't read last updated endtime for area {area_key}: {stored_endtime}.")
            continue

        current_endtime = get_current_endtime(prices)
        area_did_update = check_area_updated(stored_endtime, current_endtime, area_key)
        if area_did_update:
            logger.debug(f"Area {area_key} did update.")
            updated_areas.append(area_key)
        else:
            logger.debug(f"Area {area_key} did not update.")

    return updated_areas


async def write_updated_areas_endtimes(
    config: Config, areas_prices: Box[str, Box], updated_areas: list[str]
):
    """Write the endtimes for the areas which got updated.

    :param areas_prices, updated_areas: All updated areas must be present in the area prices.
    """
    config.paths.price_data_dir.mkdir(parents=True, exist_ok=True)

    for area_key in updated_areas:
        prices = areas_prices[area_key]
        endtime = get_current_endtime(prices)
        pickled_endtime = pickle.dumps(endtime)

        file_name = rules.LAST_UPDATED_ENDTIME_FILE_NAME.format(area_key.lower())
        file_path = config.paths.price_data_dir / file_name
        temp_file_path = file_path.with_suffix(file_path.suffix + ".tmp")

        async with async_open(temp_file_path, "wb") as file:
            await file.write(pickled_endtime)
        os.replace(temp_file_path, file_path)
        logger.debug(f"Wrote new endtime for area {area_key}.")


def get_notifiable_areas_prices(areas_prices: Box) -> Box[str, NotifiablePriceData]:
    """Get the prices for which users should be notified for."""
    notifiable_areas_prices = Box()
    for area_key, prices_data in areas_prices.items():
        notifiable_prices = get_notifiable_prices(prices_data)
        if notifiable_prices is None:
            logger.debug(f"No notifiable prices for area {area_key}.")
            continue
        notifiable_prices_data = Box()
        for key, value in prices_data.items():
            if key == "prices":
                continue
            notifiable_prices_data[key] = value
        notifiable_prices_data.prices = notifiable_prices
        notifiable_areas_prices[area_key] = NotifiablePriceData(notifiable_prices_data)

    return notifiable_areas_prices
