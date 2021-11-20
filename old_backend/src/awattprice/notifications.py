# -*- coding: utf-8 -*-

"""

Check which users apply to receive certain notifications.
Send notifications via APNs to those users.

"""

import asyncio
import json

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
from fastapi import status
from loguru import logger as log
from tenacity import retry, stop_after_attempt, stop_after_delay, wait_exponential  # type: ignore

from awattprice import poll
from awattprice.defaults import CURRENT_VAT, Region
from awattprice.token_manager import APNsTokenManager
from awattprice.types import APNSToken
from awattprice.utils import before_log


class DetailedPriceData:
    def __init__(self, data: Box, region_identifier: int):
        self.data = data
        self.region_identifier = region_identifier

    def get_user_prices(
        self, below_value: int, region_identifier: int, vat_selection: int
    ) -> Tuple[List, Optional[int]]:
        """Returns a list of prices which drop below or on a certain value. Also returns a
        integer which represents the lowest price point in the returned list.
        The marketprices of the price points in the returned list have VAT added if the user selected it (if vat_selection is 1).
        """
        below_price_data = []
        lowest_index = None

        current_index = 0
        for price_point in self.data.prices:
            now_timezone = arrow.utcnow().to("Europe/Berlin")

            midnight = now_timezone.replace(hour=0, minute=0, second=0, microsecond=0)
            tomorrow_boundary_start = midnight.shift(days=+1)
            tomorrow_boundary_end = midnight.shift(days=+2)

            marketprice_with_vat = None
            if region_identifier == 0 and vat_selection == 1:
                marketprice_with_vat = round(price_point.marketprice * CURRENT_VAT, 2)
            else:
                marketprice_with_vat = round(price_point.marketprice, 2)

            if (
                price_point.start_timestamp >= tomorrow_boundary_start.timestamp
                and price_point.end_timestamp <= tomorrow_boundary_end.timestamp
            ):
                if marketprice_with_vat <= below_value:
                    below_price_data.append(
                        Box(
                            {
                                "start_timestamp": price_point.start_timestamp,
                                "marketprice": marketprice_with_vat,
                            }  # Don't store end timestamp because a price point is always 1 hour long
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
    body_loc_key_sing = "notifications.price_drops_below.body.sing"  # Price drops below value only once
    body_loc_key_mult = "notifications.price_drops_below.body.mult"  # Price drops below value multiple times
    collapse_id = "collapse.priceDropsBelowNotification.3DK203W0"

    def get_body_loc_key(self, count: int) -> str:
        if count == 1:
            return self.body_loc_key_sing
        else:
            return self.body_loc_key_mult


class Notifications:

    _is_initialized = False

    def __init__(self, config: ConfigUpdater) -> None:
        self.below_notification = PriceDropsBelow()
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


async def handle_apns_response(db_manager, token, response, status_code, config):
    # For reference of returned response and status codes see:
    # https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/handling_notification_responses_from_apns
    if status_code == status.HTTP_200_OK:
        log.debug(f"APNs notification sent successful.")
        return
    if status_code in [status.HTTP_400_BAD_REQUEST, status.HTTP_410_GONE]:
        remove_token = False
        if status_code == status.HTTP_410_GONE and response["reason"] == "Unregistered":
            remove_token = True

        if status_code == status.HTTP_400_BAD_REQUEST and response["reason"] in [
            "BadDeviceToken",
            "DeviceTokenNotForTopic",
        ]:
            remove_token = True

        if remove_token is True:
            token_config = APNSToken(
                token=token, region_identifier=0, vat_selection=0, config={}
            )  # Populate with token and some placeholder values
            token_manager = APNsTokenManager(token_config, db_manager)
            if not config.general.debug_mode:
                token_manager.remove_entry()
            log.debug(f"Removed invalid APNs token from database: {response}.")


@retry(
    before=before_log(log, "debug"),
    stop=(stop_after_delay(60) | stop_after_attempt(8)),
    wait=wait_exponential(multiplier=1, min=4, max=10),
    reraise=True,
)
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
        lowest_price_start = arrow.get(lowest_point.start_timestamp).to("Europe/Berlin")

        if isinstance(lowest_point.marketprice, float):
            if lowest_point.marketprice.is_integer():
                lowest_price_string = "{:.0f}".format(lowest_point.marketprice)
            else:
                lowest_price_string = "{:.2f}".format(round(lowest_point.marketprice, 2))
        elif isinstance(lowest_point.marketprice, int):
            lowest_price_string = "{:.0f}".format(lowest_point.marketprice)
        else:
            lowest_price_string = "{:.2f}".format(round(lowest_point.marketprice, 2))
        formatted_lowest_price = lowest_price_string.replace(".", ",")

        if isinstance(below_value, float):
            if below_value.is_integer():
                below_value_string = "{:.0f}".format(below_value)
            else:
                below_value_string = "{:.2f}".format(round(below_value, 2))
        elif isinstance(below_value, int):
            below_value_string = "{:.0f}".format(below_value)
        else:
            below_value_string = "{:.2f}".format(round(below_value, 2))
        formatted_below_value = below_value_string.replace(".", ",")

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
                    "title-loc-key": notification_defaults.below_notification.title_loc_key,
                    "loc-key": notification_defaults.below_notification.get_body_loc_key(len(below_price_data)),
                    "loc-args": [
                        len(below_price_data),
                        formatted_below_value,
                        lowest_price_start.form        # Full cents, for example 4
        lowest_price_floored = floor(lowest_point.marketprice)
        # Decimal places of cent, for example 39
        lowest_price_decimal = round((lowest_point.marketprice - lowest_price_floored) * 100)
        # Together 4,39
        formatted_lowest_price = f"{lowest_price_floored},{lowest_price_decimal}"
        below_value_floored = floor(below_value)
        below_value_decimal = round((below_value - below_value_floored) * 100)
        formatted_below_value = f"{below_value_floored},{below_value_decimal}"at("H"),
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
            "apns-expiration": f"{lowest_price_start.timestamp + 3600}",
            "apns-priority": "5",
            "apns-collapse-id": notification_defaults.below_notification.collapse_id,
        }
     
        url = f"{notification_defaults.apns_server_url}:{notification_defaults.apns_server_port}{notification_defaults.url_path.format(token)}"
        status_code = None
        response = None

        async with httpx.AsyncClient(http2=True) as client:
            try:
                response = await client.post(url, headers=request_headers, data=json.dumps(notification_payload))
            except httpx.ConnectTimeout:
                log.warning(f"Connect attempt to {url} timed out.")
                raise
            except httpx.ReadTimeout:
                log.warning(f"Read from {url} timed out.")
                raise
            except Exception as e:
                log.warning(f"Unrecognized exception at POST request to {url}: {e}.")
                raise
            else:
                status_code = response.status_code

                if response.content.decode("utf-8") == "":
                    data = {}
                else:
                    try:
                        data = response.json()
                    except json.JSONDecodeError as e:
                        log.warning(f"Couldn't decode response from APNs servers: {e}")
                        raise
                    except Exception as e:
                        log.warning(f"Unknown error while decoding response from APNs servers: {e}")
                        raise

        if response is not None and status_code is not None:
            await handle_apns_response(db_manager, token, data, status_code, config)


async def check_and_send(config, data, data_region, db_manager):
    # Check which users apply to receive certain notifications and send them to those users.

    log.info("Checking and sending notifications.")
    notification_defaults = Notifications(config)

    if not notification_defaults.is_initialized:
        return

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
                task[0](*[task[i] for i in range(1, 9)])
            )
        )

    await asyncio.gather(*tasks)
    await db_manager.release_lock()
    log.info("All notifications checked (and sent) and all connections closed.")
