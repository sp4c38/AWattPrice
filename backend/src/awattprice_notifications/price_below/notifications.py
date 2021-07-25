"""Send price below notifications."""
import asyncio
import json

import awattprice
import httpx

from awattprice.defaults import Region
from awattprice.orm import Token
from box import Box
from http import HTTPStatus
from liteconfig import Config
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import AsyncSession

from awattprice_notifications import defaults as notification_defaults
from awattprice_notifications.apns import get_apns_authorization
from awattprice_notifications.notifications import send_notification
from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below.prices import DetailedPriceData


def construct_notification_headers(prices_below: list[Box], apns_authorization: str, use_sandbox: bool) -> Box:
    """Construct the headers for a token when sending a price below notification."""
    latest_price_below = max(prices_below, key=lambda price_point: price_point.start_timestamp)

    headers = Box()
    headers["authorization"] = f"bearer {apns_authorization}"
    headers["apns-push-type"] = defaults.NOTIFICATION.push_type
    headers["apns-priority"] = str(defaults.NOTIFICATION.priority)
    headers["apns-collapse-id"] = defaults.NOTIFICATION.collapse_id
    if use_sandbox is False:
        headers["apns-topic"] = awattprice.defaults.APP_BUNDLE_ID.production
    else:
        headers["apns-topic"] = awattprice.defaults.APP_BUNDLE_ID.sandbox
    headers["apns-expiration"] = str(latest_price_below.start_timestamp.int_timestamp)

    return headers


def construct_notification(token: Token, detailed_prices: DetailedPriceData, prices_below: list[Box]) -> Box:
    """Construct the notification for a token.

    :param prices_below: List of prices considered below the value. They must all are present in the detailed prices.
        This list is not allowed to be empty.
    """
    if len(prices_below) == 0:
        raise ValueError("Prices below the value must contain at least one price point.")

    len_prices_below_str = str(len(prices_below))
    below_value_str = str(token.price_below.below_value)
    lowest_price = detailed_prices.lowest_price
    lowest_price_start_str = lowest_price.start_timestamp.format("HH")
    lowest_price_marketprice_str = str(lowest_price.marketprice.ct_kwh())

    notification = Box()
    notification.aps = {}
    notification.aps["badge"] = 0
    notification.aps["sound"] = defaults.NOTIFICATION.sound
    notification.aps["content-available"] = 0
    notification.aps["alert"] = {}
    notification.aps["alert"]["title-loc-key"] = defaults.NOTIFICATION.title_loc_key
    if len(prices_below) == 1:
        notification.aps["alert"]["loc-key"] = defaults.NOTIFICATION.loc_keys.single_price
    else:
        notification.aps["alert"]["loc-key"] = defaults.NOTIFICATION.loc_keys.multiple_prices
    notification.aps["alert"]["loc-args"] = [
        len_prices_below_str,
        below_value_str,
        lowest_price_start_str,
        lowest_price_marketprice_str,
    ]

    return notification


async def handle_apns_response(session: AsyncSession, token: Token, response: httpx.Response):
    """Handle an apns response for a price below notification."""
    print(token.token)
    print(response.content)
    try:
        status = Box(response.json())
    except json.JSONDecodeError as exc:
        logger.exception("Couldn't load apns response json: {exc}.")
        return
    status_code = response.status_code

    if status_code == HTTPStatus.OK:
        logger.debug("Notification to token {token.token} sent successfully.")
    elif status_code == HTTPStatus.GONE:
        if status.reason == "Unregistered":
            logger.debug(f"Deleting token {token.token} as it isn't valid anymore.")
            session.delete(token)
    else:
        logger.error(f"Error sending notification to apns: {status_code} - {status}.")
        return


async def deliver_notifications(
    engine: AsyncEngine,
    config: Config,
    regions_tokens: dict[Region, list[Token]],
    price_data: dict[Region, DetailedPriceData],
):
    """Send price below notifications for certain tokens.

    :param tokens, price_data: Each region which has applying tokens *must* also be present in the price data.
    """

    apns_authorization = await get_apns_authorization(config)

    notifications_infos = []
    for region, tokens in regions_tokens.items():
        if tokens is None:
            continue

        region_prices = price_data[region]

        for token in tokens:
            prices_below = region_prices.get_prices_below_value(token.price_below.below_value, token.tax)

            headers = construct_notification_headers(prices_below, apns_authorization, config.use_sandbox)
            notification = construct_notification(token, region_prices, prices_below)

            notification_info = Box(token=token, headers=headers, notification=notification)
            notifications_infos.append(notification_info)

    async with httpx.AsyncClient(http2=True) as client:
        send_tasks = []
        for info in notifications_infos:
            send_tasks.append(
                send_notification(client, info.token, info.headers, info.notification, config.apns.use_sandbox)
            )
        logger.info(f"Sending {len(send_tasks)} notification(s).")
        responses = await asyncio.gather(*send_tasks, return_exceptions=True)

    async with AsyncSession(engine) as session:
        handle_response_tasks = []
        for info, response in zip(notifications_infos, responses):
            if isinstance(response, Exception) is True:
                logger.warning(f"Couldn't send notification: {response}.")
                continue
            handle_response_tasks.append(handle_apns_response(session, info.token, response))
        await asyncio.gather(*handle_response_tasks)
        await session.commit()
