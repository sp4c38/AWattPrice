import asyncio

import arrow
import httpx
import jwt
import json
import socket

from awattprice import poll
from awattprice.defaults import Region, Notifications

from box import Box
from datetime import datetime
from dateutil.tz import tzstr
from loguru import logger as log

async def price_drops_below_notification(notification_defaults, config, price_data, token, below_value):
    lowest_price = price_data.lowest_price
    if lowest_price < below_value:
        log.debug("Sending \"Price Drops Below\" notification to a user.")
        timezone = tzstr("CET-1CEST,M3.5.0/2,M10.5.0/3").tzname(datetime.fromtimestamp(price_data.lowest_price_point.start_timestamp))
        lowest_price_start = arrow.get(price_data.lowest_price_point.start_timestamp).to(timezone)
        lowest_price_end = arrow.get(price_data.lowest_price_point.end_timestamp).to(timezone)

        formatted_time_range = f"{lowest_price_start.format('H')} - {lowest_price_end.format('H')}"

        awattprice_bundle_id = notification_defaults.bundle_id
        encryption_algorithm = notification_defaults.encryption_algorithm

        # Set token data
        # For reference see: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns
        token_body = {"iss": notification_defaults.dev_team_id,
                      "iat": arrow.utcnow().timestamp,}

        token_headers = {"alg": notification_defaults.encryption_algorithm,
                         "kid": notification_defaults.encryption_key_id,}

        token = jwt.encode(
            token_body,
            notification_defaults.encryption_key,
            algorithm = encryption_algorithm,
            headers = token_headers,
        )

        # Set notification payload
        # For reference see: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_a_remote_notification#2943365
        notification_payload = {
            "aps": {
                "alert": {
                    "title-loc-key": notification_defaults.price_drops_below_notification.title_loc_key,
                    "loc-key": notification_defaults.price_drops_below_notification.body_loc_key,
                    "loc-args": [formatted_time_range, lowest_price],
                },
                "badge": 1,
                "sound": "default",
                "content-available": 0,
            }
        }
        request_headers = {
            "authorization": f"bearer {token}",
            "apns-push-type": "alert",
            "apns-topic": notification_defaults.bundle_id,
            "apns-expiration": f"{lowest_price_start.timestamp - 3600}",
            "apns-priority": "5",
            "apns-collapse-id": notification_defaults.price_drops_below_notification.collapse_id
        }

        url = f"{notification_defaults.apns_server_url}:{notification_defaults.apns_server_port}{notification_defaults.url_path.format(token)}"
        print(url)
        async with httpx.AsyncClient(http2 = True) as client:
            response = await client.post(url,
                                         headers = request_headers,
                                         data = json.dumps(notification_payload))
            print(response.content)


class DetailedPriceData:
    def __init__(self, data: Box, region_identifier: int):
        self.data = data
        self.region_identifier = region_identifier
        self.lowest_price = None
        self.lowest_price_point = None
        self.timedata = [] # Only contains current and future prices

        now = arrow.utcnow()
        now_hour_start = now.replace(minute = 0, second = 0, microsecond = 0)
        for price_point in self.data.prices:
            if price_point.start_timestamp >= now_hour_start.timestamp:
                marketprice = round(price_point.marketprice, 2)
                if self.lowest_price == None or marketprice < self.lowest_price:
                    self.lowest_price = marketprice
                    self.lowest_price_point = price_point

async def check_and_send(config, data, data_region, db_manager):
    log.info("Checking and sending notifications.")
    log.debug(f"Need to check and send notifications for data region {data_region.name}.")

    notification_defaults = Notifications(config,)

    all_data_to_check = {}
    all_data_to_check[data_region.value] = DetailedPriceData(Box(data), data_region.value)
    del data

    await db_manager.acquire_lock()
    # try:
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
                await notification_queue.put((
                    price_drops_below_notification,
                    notification_defaults,
                    config,
                    all_data_to_check[notifi_config["region_identifier"]],
                    token,
                    below_value))

    tasks = []
    while notification_queue.empty() == False:
        task = await notification_queue.get()
        tasks.append(asyncio.create_task(task[0](task[1], task[2], task[3], task[4], task[5])))

    await asyncio.gather(*tasks)
    log.debug("All notification configurations checked and all connections closed.")
    # except Exception as e:
        # Catch exception to be able to release lock, also if an error occurred
        # log.warning(f"Exception when trying to check and send notifications: {e}")

    del notification_defaults
    await db_manager.release_lock()
