"""Send price notification alerts."""
import asyncio
import json

import httpx

from awattprice import defaults as awattprice_defaults
from awattprice.utils import round_subunitkwh
from awattprice_notifications import utils as awattprice_notification_utils
from box import Box
from decimal import Decimal
from http import HTTPStatus
from liteconfig import Config
from loguru import logger

from awattprice_notifications.apns import get_apns_authorization
from awattprice_notifications.notifications import send_notification
from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below.prices import NotifiableDetailedPriceData


def format_price_timestamp(price_timestamp, resolution: str) -> str:
    """Format a price timestamp for notifications."""
    if resolution == "PT60M":
        return price_timestamp.format("H")
    return price_timestamp.format("H:mm")


def construct_notification_headers(apns_authorization: str, selected_prices: list[Box], rule_type: str) -> Box:
    """Construct APNs headers for a notification rule."""
    latest_price = max(selected_prices, key=lambda price_point: price_point.start_timestamp)

    headers = Box()
    headers["authorization"] = f"bearer {apns_authorization}"
    headers["apns-push-type"] = defaults.NOTIFICATION.push_type
    headers["apns-priority"] = str(defaults.NOTIFICATION.priority)
    headers["apns-collapse-id"] = defaults.NOTIFICATION.collapse_ids[rule_type]
    headers["apns-topic"] = awattprice_defaults.APP_BUNDLE_ID.production
    headers["apns-expiration"] = str(latest_price.start_timestamp.int_timestamp)

    return headers


def adjusted_price(price_point: Box, profile: Box, round_: bool = True) -> Decimal:
    """Return the user's final price for a price point."""
    marketprice = price_point.marketprice.subunit_kwh(taxed=profile.general.tax, round_=round_)
    return marketprice * (1 + profile.general.percentage_add_on / 100) + profile.general.base_fee


def stringify_adjusted_price(price_point: Box, profile: Box) -> str:
    """Return a localized string for the user's final price."""
    area = awattprice_defaults.get_market_area(profile.general.area)
    price_value = adjusted_price(price_point, profile)
    return awattprice_notification_utils.stringify_price(price_value, area)


def copy_profile_with_rule_threshold(profile: Box, rule_type: str, threshold: Decimal) -> Box:
    """Return a shallow profile copy with one threshold replaced for example construction."""
    updated_profile = Box(profile.to_dict())
    updated_profile.general.base_fee = Decimal(str(updated_profile.general.base_fee))
    updated_profile.general.percentage_add_on = Decimal(str(updated_profile.general.percentage_add_on))
    updated_profile.rules[rule_type].threshold = threshold
    return updated_profile


def construct_notification(profile: Box, rule_type: str, selected_prices: list[Box], notifiable_prices: NotifiableDetailedPriceData) -> Box:
    """Construct the APNs payload for a notification rule."""
    if len(selected_prices) == 0:
        raise ValueError("Selected prices must contain at least one price point.")

    notification = Box()
    notification.aps = {}
    notification.aps["badge"] = 0
    notification.aps["sound"] = defaults.NOTIFICATION.sound
    notification.aps["content-available"] = 0
    notification.aps["alert"] = {}
    notification.aps["alert"]["title-loc-key"] = defaults.NOTIFICATION.title_loc_keys[rule_type]

    if rule_type == "price_below":
        threshold = round_subunitkwh(Decimal(str(profile.rules.price_below.threshold)))
        best_price = min(selected_prices, key=lambda price_point: adjusted_price(price_point, profile))
        threshold_str = awattprice_notification_utils.stringify_price(
            threshold, awattprice_defaults.get_market_area(profile.general.area)
        )
        best_time = format_price_timestamp(best_price.start_timestamp, notifiable_prices.data.resolution)
        best_price_str = stringify_adjusted_price(best_price, profile)
        loc_key = defaults.NOTIFICATION.loc_keys.price_below_single
        if len(selected_prices) > 1:
            loc_key = defaults.NOTIFICATION.loc_keys.price_below_multiple
        notification.aps["alert"]["loc-key"] = loc_key
        notification.aps["alert"]["loc-args"] = [str(len(selected_prices)), threshold_str, best_time, best_price_str]
    elif rule_type == "price_above":
        threshold = round_subunitkwh(Decimal(str(profile.rules.price_above.threshold)))
        worst_price = max(selected_prices, key=lambda price_point: adjusted_price(price_point, profile))
        threshold_str = awattprice_notification_utils.stringify_price(
            threshold, awattprice_defaults.get_market_area(profile.general.area)
        )
        worst_time = format_price_timestamp(worst_price.start_timestamp, notifiable_prices.data.resolution)
        worst_price_str = stringify_adjusted_price(worst_price, profile)
        loc_key = defaults.NOTIFICATION.loc_keys.price_above_single
        if len(selected_prices) > 1:
            loc_key = defaults.NOTIFICATION.loc_keys.price_above_multiple
        notification.aps["alert"]["loc-key"] = loc_key
        notification.aps["alert"]["loc-args"] = [str(len(selected_prices)), threshold_str, worst_time, worst_price_str]
    elif rule_type == "daily_summary":
        best_price = min(notifiable_prices.data.prices, key=lambda price_point: adjusted_price(price_point, profile))
        worst_price = max(notifiable_prices.data.prices, key=lambda price_point: adjusted_price(price_point, profile))
        notification.aps["alert"]["loc-key"] = defaults.NOTIFICATION.loc_keys.daily_summary
        notification.aps["alert"]["loc-args"] = [
            format_price_timestamp(best_price.start_timestamp, notifiable_prices.data.resolution),
            stringify_adjusted_price(best_price, profile),
            format_price_timestamp(worst_price.start_timestamp, notifiable_prices.data.resolution),
            stringify_adjusted_price(worst_price, profile),
        ]
    else:
        raise ValueError(f"Unknown notification rule type: {rule_type}.")

    return notification


async def handle_apns_response(profile_store, profile: Box, response: httpx.Response):
    """Handle an APNs response for a notification."""
    status_code = response.status_code
    if len(response.content) != 0:
        try:
            status = Box(response.json())
        except json.JSONDecodeError as exc:
            logger.exception(f"Couldn't load apns {status_code} response json: {exc}.")
            return
    else:
        status = None

    if status_code == HTTPStatus.OK:
        logger.debug(f"Notification to token {profile.token} sent successfully.")
        return

    if status is None:
        logger.error(f"Unsuccessful apns request but no reason returned: {status_code}.")
        return

    if status_code == HTTPStatus.GONE:
        if status.reason == "Unregistered":
            logger.debug(f"Deleting token {profile.token} as it isn't valid anymore.")
            profile_store.delete_profile(profile.token)
    else:
        logger.error(f"Error sending notification with token {profile.token} to apns: {status_code} - {status}. Doing nothing with this token.")


def selected_prices_for_rule(profile: Box, rule_type: str, notifiable_prices: NotifiableDetailedPriceData) -> list[Box]:
    """Return prices that make a rule apply."""
    if rule_type == "daily_summary":
        return list(notifiable_prices.data.prices)

    if rule_type == "price_below":
        threshold = Decimal(str(profile.rules.price_below.threshold))
        return [
            price_point for price_point in notifiable_prices.data.prices
            if adjusted_price(price_point, profile) <= threshold
        ]

    if rule_type == "price_above":
        threshold = Decimal(str(profile.rules.price_above.threshold))
        return [
            price_point for price_point in notifiable_prices.data.prices
            if adjusted_price(price_point, profile) >= threshold
        ]

    raise ValueError(f"Unknown notification rule type: {rule_type}.")


def forced_example_for_rule(
    profile: Box, rule_type: str, notifiable_prices: NotifiableDetailedPriceData
) -> tuple[Box, list[Box]]:
    """Return a profile and selected prices that force a representative rule example."""
    if rule_type == "daily_summary":
        return profile, selected_prices_for_rule(profile, rule_type, notifiable_prices)

    if rule_type == "price_below":
        best_price = min(notifiable_prices.data.prices, key=lambda price_point: adjusted_price(price_point, profile))
        threshold = round_subunitkwh(adjusted_price(best_price, profile))
        return copy_profile_with_rule_threshold(profile, rule_type, threshold), [best_price]

    if rule_type == "price_above":
        worst_price = max(notifiable_prices.data.prices, key=lambda price_point: adjusted_price(price_point, profile))
        threshold = round_subunitkwh(adjusted_price(worst_price, profile))
        return copy_profile_with_rule_threshold(profile, rule_type, threshold), [worst_price]

    raise ValueError(f"Unknown notification rule type: {rule_type}.")


def active_rule_types(profile: Box) -> list[str]:
    """Return active rule type names for a profile."""
    rules = []
    if profile.rules.price_below.active:
        rules.append("price_below")
    if profile.rules.price_above.active:
        rules.append("price_above")
    if profile.rules.daily_summary.active:
        rules.append("daily_summary")
    return rules


async def deliver_notifications(
    profile_store,
    config: Config,
    areas_profiles: Box[str, list[Box]],
    notifiable_areas_prices: Box[str, NotifiableDetailedPriceData],
):
    """Send notifications for profiles grouped by area.

    :param areas_profiles, notifiable_areas_prices: Each area with profiles *must* also be present in the price data.
    """

    apns_authorization = await get_apns_authorization(config)

    notifications_infos = []
    for area_key, profiles in areas_profiles.items():
        if profiles is None:
            continue

        notifiable_prices = notifiable_areas_prices[area_key]

        for profile in profiles:
            for rule_type in active_rule_types(profile):
                selected_prices = selected_prices_for_rule(profile, rule_type, notifiable_prices)
                if not selected_prices:
                    continue

                headers = construct_notification_headers(apns_authorization, selected_prices, rule_type)
                notification = construct_notification(profile, rule_type, selected_prices, notifiable_prices)
                notification_info = Box(profile=profile, headers=headers, notification=notification)
                notifications_infos.append(notification_info)

    async with httpx.AsyncClient(http2=True) as client:
        send_tasks = []
        for info in notifications_infos:
            send_tasks.append(send_notification(client, info.profile, info.headers, info.notification))
        logger.info(f"Sending {len(send_tasks)} notification(s).")
        responses = await asyncio.gather(*send_tasks, return_exceptions=True)

    handle_response_tasks = []
    for info, response in zip(notifications_infos, responses):
        if isinstance(response, Exception) is True:
            logger.warning(f"Couldn't send notification: {response}.")
            continue
        handle_response_tasks.append(handle_apns_response(profile_store, info.profile, response))
    await asyncio.gather(*handle_response_tasks)
