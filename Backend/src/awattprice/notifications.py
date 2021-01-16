# -*- coding: utf-8 -*-

"""

Check which users apply to receive certain notifications.
Send notifications via APNs to those users.

"""

import asyncio
import json

from copy import copy
from datetime import datetime
from math import floor
from pathlib import Path
from typing import List, Optional, Tuple

import arrow  # type: ignore
import httpx
import jwt

from box import Box  # type: ignore
from configupdater import ConfigUpdater  # type: ignore
from dateutil.tz import tzstr
from loguru import logger as log

from awattprice import poll
from awattprice.defaults import CURRENT_VAT, Region
from awattprice.token_manager import APNsTokenManager


class DetailedPriceData:
    def __init__(self, data: Box, region_identifier: int):
        self.data = data
        self.region_identifier = region_identifier

    def get_user_prices(
        self, below_value: int, region_identifier: int, vat_selection: int
    ) -> Tuple[List, Optional[int]]:
        """Returns a list of prices which drop below or on a certain value. Also returns a
        integer which represents the lowest price point in the returned list.
        The price point marketprices in the returned list have the VAT added if the user selected it (if vat_selection is 1).
        """
        below_price_data = []
        lowest_index = None

        current_index = 0
        for price_point in self.data.prices:
            timezone = tzstr("CET-1CEST,M3.5.0/2,M10.5.0/3").tzname(datetime.fromtimestamp(price_point.start_timestamp))
            now = arrow.utcnow().to(timezone)

            now_day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            tomorrow_hour_start = now_day_start.shift(days=+1)

            if region_identifier == 0 and vat_selection == 1:
                marketprice_with_vat = round(price_point.marketprice * CURRENT_VAT, 2)
            else:
                marketprice_with_vat = price_point.marketprice

            # Only check price points for the next day. So price points for the
            # current day were already checked a day before.
            if price_point.start_timestamp >= tomorrow_hour_start.timestamp:
                if marketprice_with_vat <= below_value:
                    below_price_data.append(
                        Box(
                            {
                                "start_timestamp": price_point.start_timestamp,
                                "marketprice": marketprice_with_vat,
                            }  # Always one hour long
                        )
                    )

                    if lowest_index is None:
                        lowest_index = current_index
                    else:
                        if marketprice_with_vat < below_price_data[lowest_index].marketprice:
                            lowest_index = current_index

                    current_index += 1

        return below_price_data, lowest_index


class PriceDropsBelow:

    # Use localization keys which are resolved on the client side
    title_loc_key = "general.priceGuard"
    body_loc_key = "notifications.price_drops_below.body"
    collapse_id = "collapse.priceDropsBelow3DK203W0#"


class Notifications:

    _is_initialized = False

    def __init__(self, config: ConfigUpdater) -> None:
        self.price_drops_below_notification = PriceDropsBelow()
        self.encryption_algorithm = "ES256"

        try:
            dev_team_id_path = Path(config.notifications.dev_team_id).expanduser()
            self.dev_team_id = open(dev_team_id_path.as_posix(), "r").readlines()[0].replace("\n", "")
            encryption_key_id_path = Path(config.notifications.apns_encryption_key_id).expanduser()
            self.encryption_key_id = open(encryption_key_id_path.as_posix(), "r").readlines()[0].replace("\n", "")
            encryption_key_path = Path(config.notifications.apns_encryption_key).expanduser()
            self.encryption_key = open(encryption_key_path.as_posix(), "r").read()
            self.url_path = "/3/device/{}"
        except Exception as e:
            log.warning(
                f"Couldn't read or find file(s) containing required information to send notifications "
                f"with APNs. Notifications won't be checked and won't be sent by the backend: {e}."
            )
            return

        if config.notifications.use_sandbox:
            log.debug("Using sandbox APNs server.")
            self.apns_server_url = "https://api.sandbox.push.apple.com"
            self.bundle_id = "me.space8.AWattPrice.dev"
        else:
            log.debug("Using production APNs server.")
            self.apns_server_url = "https://api.push.apple.com"
            self.bundle_id = "me.space8.AWattPrice"
        self.apns_server_port = 443

        self._is_initialized = True

    @property
    def is_initialized(self):
        """Return True if __init__ was successful."""
        return self._is_initialized


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
                token_manager = APNsTokenManager({"token": token}, db_manager)
                token_manager.remove_entry()
                log.debug("Removed invalid APNs token from database.")


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
    below_price_data, lowest_index = price_data.get_user_prices(below_value, region_identifier, vat_selection)

    if below_price_data and lowest_index is not None:
        lowest_point = below_price_data[lowest_index]

        log.debug('Sending "Price Drops Below" notification to a user.')
        # Get the current timezone (either CET or CEST)
        timezone = tzstr("CET-1CEST,M3.5.0/2,M10.5.0/3").tzname(datetime.fromtimestamp(lowest_point.start_timestamp))
        lowest_price_start = arrow.get(lowest_point.start_timestamp).to(timezone)

        # Full cents, for example 4
        lowest_price_floored = floor(lowest_point.marketprice)
        # Decimal places of cent, for example 39
        lowest_price_decimal = round((lowest_point.marketprice - lowest_price_floored) * 100)
        # Together 4,39
        formatted_lowest_price = f"{lowest_price_floored},{lowest_price_decimal}"

        below_value_floored = floor(below_value)
        below_value_decimal = round((below_value - below_value_floored) * 100)
        formatted_below_value = f"{below_value_floored},{below_value_decimal}"

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

        token_data_encoded = jwt.encode(  # JWT is required by APNs for token based authentication
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
                        formatted_below_value,
                        lowest_price_start.format("H"),
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
            request = await client.post(url, headers=request_headers, data=json.dumps(notification_payload))
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
        checked_regions_no_notifications = []  # Already checked regions which don't apply to receive notifications

        await db_manager.acquire_lock()
        cursor = db_manager.db.cursor()
        items = cursor.execute("SELECT * FROM token_storage;").fetchall()
        cursor.close()
        items = [dict(x) for x in items]

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
                region = Region(region_identifier)

                if region_identifier not in all_data_to_check:
                    # Runs if a user is in a different region as those which are included in the regions
                    # to send notification updates.
                    # Therefor this polls the aWATTar API of the certain region.
                    if region.value in checked_regions_no_notifications:
                        continue
                    if region == data_region:
                        region_check_notification = True
                        region_data = data
                    else:
                        region_data, region_check_notification = await poll.get_data(config=config, region=region)

                    if region_check_notification:
                        log.debug(f"Need to check and send notifications for data region {region.name}.")
                        all_data_to_check[region.value] = DetailedPriceData(Box(region_data), region.value)
                    else:
                        log.debug(f"Don't need to check and send notifications for data region {region.name}.")
                        checked_regions_no_notifications.append(region.value)
                        continue

                token = notifi_config["token"]
                vat_selection = notifi_config["vat_selection"]

                if configuration["price_below_value_notification"]["active"] is True:
                    # If user applies to get price below value notifications add following item to queue
                    below_value = configuration["price_below_value_notification"]["below_value"]

                    await notification_queue.put(
                        (
                            price_drops_below_notification,
                            db_manager,
                            notification_defaults,
                            config,
                            all_data_to_check[region.value],
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
        log.info("All notifications checked (and sent) and all connections closed.")
