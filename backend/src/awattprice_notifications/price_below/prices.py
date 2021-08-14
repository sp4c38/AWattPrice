"""Manage and handle price data fron the main awattprice package."""
import asyncio
import pickle
import sys

from decimal import Decimal
from typing import Optional

import awattprice

from aiofile import async_open
from arrow import Arrow
from awattprice.defaults import Region
from box import Box
from liteconfig import Config
from loguru import logger

from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below.defaults import check_region_updated, get_notifiable_prices


class DetailedPriceData:
    """Describes price data in a detailed manner."""

    data: Box

    lowest_price: Optional[Box] = None

    def __init__(self, data: Box):
        self.data = data

    def find_lowest_price(self):
        """Find the lowest price."""
        lowest_price = min(self.data.prices, key=lambda price_point: price_point.marketprice.value)
        self.lowest_price = lowest_price

    def get_prices_below_value(self, below_value: Decimal, taxed: bool) -> list[int]:
        """Get prices which are on or below the given value.

        :param taxed: If true prices are taxed before comparing to the below value. This doesn't affect the
            below value.
        """
        below_value_prices = []
        for price_point in self.data.prices:
            marketprice = price_point.marketprice.ct_kwh(taxed=taxed, round_=True)
            if marketprice <= below_value:
                below_value_prices.append(price_point)

        return below_value_prices


class NotifiableDetailedPriceData(DetailedPriceData):
    """Holds price data about which users should be notified for."""

    def __init__(self, notifiable_data: Box):
        self.data = notifiable_data


async def collect_regions_prices(config: Config, regions: list[Region]) -> Box:
    """Get the current prices for multiple regions."""
    prices_tasks = [awattprice.prices.get_current_prices(region, config, fall_back=False) for region in regions]
    regions_prices = await asyncio.gather(*prices_tasks)
    regions_prices = dict(zip(regions, regions_prices))

    existing_regions_prices = {}
    for region, prices in regions_prices.items():
        if prices is None:
            logger.warning(f"Couldn't get current price data for region {region}.")
            continue
        existing_regions_prices[region] = prices

    return existing_regions_prices


async def read_last_updated_endtime(config: Config, region: Region) -> Optional[Arrow]:
    """Get the end time of the latest price point when the price data was updated last for the certain region."""
    file_name = defaults.LAST_UPDATED_ENDTIME_FILE_NAME.format(region.name.lower())
    file_path = config.paths.price_data_dir / file_name
    try:
        async with async_open(file_path, "rb") as file:
            pickled_time = await file.read()
    except FileNotFoundError as exc:
        logger.debug(f"No last updated endtime for region {region} exists yet: {exc}.")
        return None

    time = pickle.loads(pickled_time)
    return time


def get_current_endtime(prices: Box) -> Arrow:
    latest_price_point = max(prices.prices, key=lambda price_point: price_point.end_timestamp)
    current_endtime = latest_price_point.end_timestamp
    return current_endtime


async def get_updated_regions(config: Config, regions_prices: Box[Region, Box]) -> list:
    """Get the regions of which their prices updated relative to the last time they updated."""
    regions = regions_prices.keys()
    prices = regions_prices.values()

    endtimes_tasks = [read_last_updated_endtime(config, region) for region in regions]
    endtimes = await asyncio.gather(*endtimes_tasks, return_exceptions=True)

    updated_regions = []
    regions_prices_endtimes = list(zip(regions, prices, endtimes))
    for region, prices, stored_endtime in regions_prices_endtimes:
        if isinstance(stored_endtime, Exception):
            logger.exception(f"Couldn't read last updated endtime for region {region}: {exc}.")
            continue

        current_endtime = get_current_endtime(prices)
        regions_did_update = check_region_updated(stored_endtime, current_endtime)
        if regions_did_update:
            logger.debug(f"Region {region} did update.")
            updated_regions.append(region)
        else:
            logger.debug(f"Region {region} did not update.")

    return updated_regions


async def write_updated_regions_endtimes(
    config: Config, regions_prices: Box[Region, Box], updated_regions: [Region]
):
    """Write the endtimes for the regions which got updated.

    :param regions_prices, updated_regions: All updated regions must be present in the regions prices.
    """
    for region in updated_regions:
        prices = regions_prices[region]
        endtime = get_current_endtime(prices)
        pickled_endtime = pickle.dumps(endtime)

        file_name = defaults.LAST_UPDATED_ENDTIME_FILE_NAME.format(region.name.lower())
        file_path = config.paths.price_data_dir / file_name
        try:
            async with async_open(file_path, "wb") as file:
                await file.write(pickled_endtime)
            logger.debug(f"Wrote new endtime for region {region}.")
        except Exception as exc:
            logger.exception(f"Couldn't write endtime for region {region.name.lower()}: {exc}.")


def get_notifiable_regions_prices(regions_prices: Box) -> Box[Region, NotifiableDetailedPriceData]:
    """Get the prices for which users should be notified for."""
    notifiable_regions_prices = Box()
    for region, prices_data in regions_prices.items():
        notifiable_prices_data = prices_data
        notifiable_prices = get_notifiable_prices(prices_data.prices)
        if notifiable_prices is None:
            logger.debug(f"No notifiable prices for region {region}.")
            continue
        notifiable_prices_data.prices = notifiable_prices
        notifiable_detailed_prices = NotifiableDetailedPriceData(notifiable_prices_data)
        notifiable_regions_prices[region] = notifiable_detailed_prices

    return notifiable_regions_prices
