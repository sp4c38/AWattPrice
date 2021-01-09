# -*- coding: utf-8 -*-

"""

Check which users apply to receive certain notifications.
Send notifications via APNs to those users.

"""

from math import floor

import arrow
import asyncio
import httpx
import json
import jwt

from awattprice import poll
from awattprice.defaults import Region, Notifications
from awattprice.token_manager import APNs_Token_Manager

from box import Box
from datetime import datetime
from dateutil.tz import tzstr
from loguru import logger as log


class DetailedPriceData:

    def __init__(self, data: Box, region_identifier: int):
        self.data = data
        self.region_identifier = region_identifier
        self.lowest_price = None
        self.lowest_price_point = None
        self.timedata = []  # Only contains current and future prices

        for price_point in self.data.prices:
            timezone = tzstr("CET-1CEST,M3.5.0/2,M10.5.0/3").tzname(
                datetime.fromtimestamp(price_point.start_timestamp)
            )
            now = arrow.utcnow().to(timezone)
            now_day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            if price_point.start_timestamp >= now_day_start.timestamp:
                marketprice = round(price_point.marketprice, 2)
                if self.lowest_price is None or marketprice < self.lowest_price:
                    self.lowest_price = marketprice
                    self.lowest_price_point = price_point


async def handle_apns_response(db_manager, token, response, status_code):
    # For reference of returned response and status codes see: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/handling_notification_responses_from_apns
    if not status_code == 200:
        if status_code in [400, 410]:
            remove_token = False
            if status_code == 410 and response["reason"] == "Unregistered":
                remove_token = True

            if status_code == 400 and response["reason"] in [
                "BadDeviceToken",
                "DeviceTokenNotForTopic",
            ]:
                remove_token = True

            if remove_token is True:
                token_manager = APNs_Token_Manager({"token": token}, db_manager)
                await token_manager.remove_entry_from_database()
                log.debug("Removed invalid APNs token from database.")
    else:
        log.debug("Request to APNs was successful.")


async def price_drops_below_notification(
    db_manager,
    notification_defaults,
    config,
    price_data,
    token,
    below_value,
    region_identifier,
    vat_selection,
):
    if price_data.lowest_price is not None:
        lowest_price = round(price_data.lowest_price, 2)
        # User selected Germany as a region and wants VAT included in all electricity prices
        if region_identifier == 0 and vat_selection == 1:
            lowest_price = round(lowest_price * 1.16, 2)

        if lowest_price < below_value:
            log.debug('Sending "Price Drops Below" notification to a user.')
            # Get the current timezone (either CET or CEST, depending on season)
            timezone = tzstr("CET-1CEST,M3.5.0/2,M10.5.0/3").tzname(
                datetime.fromtimestamp(price_data.lowest_price_point.start_timestamp)
            )
            lowest_price_start = arrow.get(
                price_data.lowest_price_point.start_timestamp
            ).to(timezone)
            lowest_price_end = arrow.get(
                price_data.lowest_price_point.end_timestamp
            ).to(timezone)

            # Full cents, for example 4
            lowest_price_cent = floor(lowest_price)
            # Decimal places of cent, for example 39
            lowest_price_cent_decimal = round((lowest_price - lowest_price_cent) * 100)
            # Together 4,39
            formatted_lowest_price = f"{lowest_price_cent},{lowest_price_cent_decimal}"

            encryption_algorithm = notification_defaults.encryption_algorithm

            # Set token data
            # For reference see: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns
            token_body = {
                "iss": notification_defaults.dev_team_id,
                "iat": arrow.utcnow().timestamp,
            }

            token_headers = {
                "alg": notification_defaults.encryption_algorithm,
                "kid": notification_defaults.encryption_key_id,
            }

            token_data_encoded = jwt.encode(  # Apple requires using JWT
                token_body,
                notification_defaults.encryption_key,
                algorithm=encryption_algorithm,
                headers=token_headers,
            )

            # Set notification payload
            # For reference see: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_a_remote_notification#2943365
            notification_payload = {
                "aps": {
                    "alert": {
                        "title-loc-key": notification_defaults.price_drops_below_notification.title_loc_key,
                        "loc-key": notification_defaults.price_drops_below_notification.body_loc_key,
                        "loc-args": [
                            lowest_price_start.format("DD.MM.YYYY"),
                            lowest_price_start.format("H"),
                            lowest_price_end.format("H"),
                            formatted_lowest_price,
                        ],
                    },
                    "badge": 0,
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
                "apns-collapse-id": notification_defaults.price_drops_below_notification.collapse_id,
            }

            url = f"{notification_defaults.apns_server_url}:{notification_defaults.apns_server_port}{notification_defaults.url_path.format(token)}"

            status_code = None
            response = None

            async with httpx.AsyncClient(http2=True) as client:
                request = await client.post(
                    url, headers=request_headers, data=json.dumps(notification_payload)
                )
                status_code = request.status_code

                if request.content.decode("utf-8") == "":
                    response = {}
                else:
                    try:
                        response = json.loads(request.content.decode("utf-8"))
                    except Exception as e:
                        log.warning(f"Couldn't decode response from APNs servers: {e}")

            if response is not None and status_code is not None:
                await handle_apns_response(db_manager, token, response, status_code)


async def check_and_send(config, data, data_region, db_manager):
    # Check which users apply to receive certain notifications and send them to those users.

    log.info("Checking and sending notifications.")
    notification_defaults = Notifications(config)

    if notification_defaults.is_initialized:
        all_data_to_check = {}
        log.debug(
            f"Need to check and send notifications for data region {data_region.name}."
        )
        all_data_to_check[data_region.value] = DetailedPriceData(
            Box(data), data_region.value
        )

        await db_manager.acquire_lock()
        cursor = db_manager.db.cursor()
        items = cursor.execute("SELECT * FROM token_storage;").fetchall()
        cursor.close()
        items = [dict(x) for x in items]

        log.debug(
            "Checking all stored notification configurations - if they apply to receive a notification."
        )

        notification_queue = asyncio.Queue()
        for notifi_config in items:
            try:
                configuration = json.loads(notifi_config["configuration"])["config"]
            except Exception:
                log.warning(
                    "Internally passed notification configuration of a user couldn't be read "
                    "while checking if the user should receive notifications."
                )
                continue

            # Check all notification types with following if statment to check if the user
            # wants to get any notifications at all
            if configuration["price_below_value_notification"]["active"] is True:
                region_identifier = notifi_config["region_identifier"]

                if region_identifier not in all_data_to_check:
                    # Runs if a user is in a different region as those which are included in the regions
                    # to send notification updates.
                    # Therefor this polls the aWATTar API of the certain region.

                    region = Region(region_identifier)
                    region_data, region_check_notification = await poll.get_data(
                        config=config, region=region
                    )
                    if region_check_notification:
                        log.debug(
                            f"Need to check and send notifications for data region {region.name}."
                        )
                        all_data_to_check[region.value] = DetailedPriceData(
                            Box(region_data), region.value
                        )
                    else:
                        continue

                if (
                    all_data_to_check[region_identifier].lowest_price is not None
                    and all_data_to_check[region_identifier].lowest_price_point
                    is not None
                ):
                    token = notifi_config["token"]
                    vat_selection = notifi_config["vat_selection"]

                    if (
                        configuration["price_below_value_notification"]["active"] is True
                    ):
                        # If user applies to get price below value notifications add following item to queue
                        below_value = configuration["price_below_value_notification"][
                            "below_value"
                        ]
                        await notification_queue.put(
                            (
                                price_drops_below_notification,
                                db_manager,
                                notification_defaults,
                                config,
                                all_data_to_check[region_identifier],
                                token,
                                below_value,
                                region_identifier,
                                vat_selection,
                            )
                        )

        tasks = []
        while notification_queue.empty() is False:
            task = await notification_queue.get()
            tasks.append(
                asyncio.create_task(
                    task[0](
                        task[1],
                        task[2],
                        task[3],
                        task[4],
                        task[5],
                        task[6],
                        task[7],
                        task[8],
                    )
                )
            )

        await asyncio.gather(*tasks)
        await db_manager.release_lock()
        log.debug("All notification configurations checked and all connections closed.")

    del notification_defaults
