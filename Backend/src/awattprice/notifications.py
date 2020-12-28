import asyncio

import arrow
import jwt
import json

from awattprice import poll
from awattprice.defaults import Region, Notifications

from box import Box
from loguru import logger as log

async def price_drops_below_notification(notification_defaults, config, price_data, token, below_value):
    lowest_price = price_data.lowest_price
    if lowest_price < below_value:
        log.info("User applies for receiving \"Price Drops Below\" notification.")
        encryption_algorithm = notification_defaults.encryption_algorithm
        path = notification_defaults.url_path.format(token)
        

class DetailedPriceData:
    def __init__(self, data: Box, region_identifier: int):
        self.data = data
        self.region_identifier = region_identifier
        self.lowest_price = None
        self.timedata = [] # Only contains current and future prices

        now = arrow.utcnow()
        now_hour_start = now.replace(minute = 0, second = 0, microsecond = 0)
        for price_point in self.data.prices:
            if price_point.start_timestamp >= now_hour_start.timestamp:
                marketprice = round(price_point.marketprice, 2)
                if self.lowest_price == None or marketprice < self.lowest_price:
                    self.lowest_price = marketprice

async def check_and_send(config, data, data_region, db_manager):
    log.info("Checking and sending notifications.")
    log.debug(f"Need to check and send notifications for data region {data_region.name}.")

    notification_defaults = Notifications(config,)

    all_data_to_check = {}
    all_data_to_check[data_region.value] = DetailedPriceData(Box(data), data_region.value)
    del data

    await db_manager.acquire_lock()
    try:
        cursor = db_manager.db.cursor()
        items = cursor.execute("SELECT * FROM token_storage;").fetchall()
        items = [dict(x) for x in items]

        log.debug("Checking all stored notification configurations - if they apply to receive a notification.")

        notification_queue = asyncio.Queue()

        for notifi_config in items:
            if not notifi_config["region_identifier"] in all_data_to_check:
                region = Region(notifi_config["region_identifier"])
                region_data, region_check_notification = await poll.get_data(config=config, region=region)
                if region_check_notification:
                    log.debug(f"Need to check and send notifications for data region {region.name}.")
                    all_data_to_check[region.value] = DetailedPriceData(Box(region_data), region.value)
                else:
                    continue

            if notifi_config["region_identifier"] in all_data_to_check:
                token = notifi_config["token"]
                try:
                    configuration = json.loads(notifi_config["configuration"])["config"]
                except:
                    log.warning("Internally passed notification configuration of a client couldn't be read "\
                                "when checking if he should receive notifications.")

                if configuration["price_below_value_notification"]["active"] == True:
                    below_value = configuration["price_below_value_notification"]["below_value"]
                    await notification_queue.put(asyncio.create_task(
                        price_drops_below_notification(
                        notification_defaults,
                        config,
                        all_data_to_check[notifi_config["region_identifier"]],
                        token,
                        below_value)))

        while notification_queue.empty() == False:
            task = await notification_queue.get()
            await task
    except Exception as e:
        # Catch exception to be able to release lock, also if an error occurred
        print(e)

    del notification_defaults
    await db_manager.release_lock()
