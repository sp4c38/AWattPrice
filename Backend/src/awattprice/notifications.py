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

async def price_drops_below_notification(notification_defaults, config, price_data, token, below_value, region_identifier, vat_selection):
    lowest_price = round(price_data.lowest_price, 2)
    if region_identifier == 0 and vat_selection == 1: # User selected Germany as a region and wants VAT included in all electricity prices
        lowest_price = round(lowest_price * 1.19, 2)

    if lowest_price < below_value:
        log.debug("Sending \"Price Drops Below\" notification to a user.")
        # Get the current timezone (either CET or CEST, depending on season)
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

        token_data_encoded = jwt.encode( # Apple requires using JWT
            token_body,
            notification_defaults.encryption_key,
            algorithm = encryption_algorithm,
            headers = token_headers,
        )
        # print(token_body)
        # print(token_headers)

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

        # Set request headers
        # For reference see: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/sending_notification_requests_to_apns
        request_headers = {
            "authorization": f"bearer {token_data_encoded}",
            "apns-push-type": "alert",
            "apns-topic": notification_defaults.bundle_id,
            "apns-expiration": f"{lowest_price_start.timestamp - 3600}",
            "apns-priority": "5",
            "apns-collapse-id": notification_defaults.price_drops_below_notification.collapse_id
        }

        url = f"{notification_defaults.apns_server_url}:{notification_defaults.apns_server_port}{notification_defaults.url_path.format(token)}"
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
    # Check which users apply to receive certain notifications and send them to those users.

    log.info("Checking and sending notifications.")

    notification_defaults = Notifications(config,)

    all_data_to_check = {}
    log.debug(f"Need to check and send notifications for data region {data_region.name}.")
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
        try:
            configuration = json.loads(notifi_config["configuration"])["config"]
        except:
            log.warning("Only internally passed notification configuration of a client couldn't be read "\
                        "while checking if the user should receive notifications.")
            continue

        # Check all notification types with following if statment to check if the user
        # wants to get any notifications at all
        if configuration["price_below_value_notification"]["active"] == True: # Currently only notification type which exists
            if not notifi_config["region_identifier"] in all_data_to_check:
                # Run if a user is in a different region as the current data to check includes.
                # This polls the aWATTar API of this region and checks if notification updates
                # should also be sent for that region.

                region = Region(notifi_config["region_identifier"])
                region_data, region_check_notification = await poll.get_data(config=config, region=region)
                if region_check_notification:
                    log.debug(f"Need to check and send notifications for data region {region.name}.")
                    all_data_to_check[region.value] = DetailedPriceData(Box(region_data), region.value)
                else:
                    continue

            token = notifi_config["token"]
            region_identifier = notifi_config["region_identifier"]
            vat_selection = notifi_config["vat_selection"]

            if configuration["price_below_value_notification"]["active"] == True:
                # If user wants to get price below value notifications add following item to queue
                below_value = configuration["price_below_value_notification"]["below_value"]

                await notification_queue.put((
                    price_drops_below_notification,
                    notification_defaults,
                    config,
                    all_data_to_check[notifi_config["region_identifier"]],
                    token,
                    below_value,
                    region_identifier,
                    vat_selection))

    tasks = []
    while notification_queue.empty() == False:
        task = await notification_queue.get()
        tasks.append(asyncio.create_task(task[0](task[1], task[2], task[3], task[4], task[5], task[6], task[7])))

    await asyncio.gather(*tasks)
    log.debug("All notification configurations checked and all connections closed.")

    del notification_defaults
    await db_manager.release_lock()
