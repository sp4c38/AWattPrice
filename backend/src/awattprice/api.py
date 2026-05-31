"""Define the urls and their tasks handled by the API."""
from datetime import date
from json import JSONDecodeError

from box import Box
from fastapi import FastAPI
from fastapi import HTTPException
from fastapi import Query
from fastapi import Request
from loguru import logger
from starlette.responses import Response

from awattprice import configurator
from awattprice import cache_status
from awattprice import defaults
from awattprice import generation_mix
from awattprice import notification_profiles
from awattprice import prices
from awattprice_notifications import rules as notification_defaults
from awattprice_notifications import payloads as notification_payloads
from awattprice_notifications import prices as notification_prices
from awattprice_refresher import prices as price_refresher

config = configurator.get_config()
configurator.configure_loguru(defaults.AWATTPRICE_SERVICE_NAME, config)
profile_store = notification_profiles.NotificationProfileStore(notification_profiles.get_store_path(config))

app = FastAPI()


def is_retained_history_date(history_date: date) -> bool:
    """Return true when the date belongs to the warmed history cache."""
    return history_date in cache_status.latest_history_days()


@logger.catch
@app.get("/areas/")
async def get_supported_areas():
    """Get the supported market areas."""
    areas = []
    for area in defaults.list_market_areas():
        areas.append(
            {
                "key": area.key,
                "display_name": area.display_name,
                "country_code": area.country_code,
                "entsoe_domain": area.entsoe_domain,
                "timezone": area.timezone,
                "currency": area.currency,
                "tax_multiplier": float(area.tax_multiplier) if area.tax_multiplier is not None else None,
            }
        )

    return {"default_area": defaults.DEFAULT_MARKET_AREA_KEY, "areas": areas}


@logger.catch
@app.get("/prices/{area_key}")
async def get_area_prices(area_key: str):
    """Get current price data for a market area."""
    try:
        normalized_area_key = defaults.normalize_market_area_key(area_key)
        area = defaults.get_market_area(normalized_area_key)
    except KeyError:
        raise HTTPException(404)

    price_data = await prices.get_stored_data(normalized_area_key, config)

    if price_data is None or not prices.has_current_price_points(price_data, area):
        logger.warning(f"Couldn't get current price data for area {normalized_area_key}.")
        raise HTTPException(503)

    response_price_data = prices.parse_to_response_data(price_data)

    return response_price_data


@logger.catch
@app.get("/prices/{area_key}/history/{history_date}")
async def get_area_price_history(area_key: str, history_date: date):
    """Get historical price data for a market area and local date."""
    try:
        normalized_area_key = defaults.normalize_market_area_key(area_key)
        area = defaults.get_market_area(normalized_area_key)
    except KeyError:
        raise HTTPException(404)

    if not prices.validate_history_date(area, history_date):
        raise HTTPException(400)

    price_data = await prices.get_stored_history_data(normalized_area_key, history_date, config)
    if price_data is None and not is_retained_history_date(history_date):
        try:
            price_data = await price_refresher.download_history_prices(normalized_area_key, history_date, config)
        except Exception as exc:
            logger.warning(
                f"Couldn't download uncached historical price data for area "
                f"{normalized_area_key} and date {history_date}: {exc}."
            )

    if price_data is None:
        logger.warning(f"Couldn't get historical price data for area {normalized_area_key} and date {history_date}.")
        raise HTTPException(503)

    return prices.parse_to_response_data(price_data)


@logger.catch
@app.get("/generation-mix/{area_key}/history")
async def get_area_generation_mix_history_for_hours(area_key: str, hours: int = Query(..., ge=168, le=168)):
    """Get grouped generation mix history for a market area (only hours=168 is supported)."""
    try:
        normalized_area_key = defaults.normalize_market_area_key(area_key)
        defaults.get_market_area(normalized_area_key)
    except KeyError:
        raise HTTPException(404)

    cached_response_json = await generation_mix.get_stored_history_response_json(normalized_area_key, hours, config)
    if cached_response_json is not None:
        return Response(content=cached_response_json, media_type="application/json")

    logger.warning(f"Couldn't get generation mix history for area {normalized_area_key}.")
    raise HTTPException(503)


@logger.catch
@app.get("/cache/status")
async def get_cache_status():
    """Get internal cache coverage and freshness status."""
    return await cache_status.cache_status_response(config)


@logger.catch
@app.put("/notifications/device/")
async def put_notification_profile(request: Request):
    """Replace the notification profile for a device token."""
    try:
        body_json = await request.json()
    except JSONDecodeError as exc:
        body_raw = await request.body()
        logger.warning(f"Couldn't decode notification profile {repr(body_raw)} as json: {exc}.")
        raise HTTPException(400)

    raw_profile = Box(body_json)

    profile = notification_profiles.parse_notification_profile_body(raw_profile)
    if profile is None:
        raise HTTPException(400)

    profile_store.save_profile(profile)
    return Response(status_code=204)


@logger.catch
@app.post("/notifications/examples/{rule_type}/")
async def get_notification_example(rule_type: str, request: Request):
    """Return the localized APNs alert payload for an example notification rule."""
    if rule_type not in notification_defaults.NOTIFICATION.collapse_ids:
        raise HTTPException(404)

    try:
        body_json = await request.json()
    except JSONDecodeError as exc:
        body_raw = await request.body()
        logger.warning(f"Couldn't decode notification example profile {repr(body_raw)} as json: {exc}.")
        raise HTTPException(400)

    body = Box(body_json)
    force = bool(body.pop("force", False))

    profile = notification_profiles.parse_notification_profile_body(body)
    if profile is None:
        raise HTTPException(400)

    price_data = await prices.get_stored_data(profile.general.area, config)
    if price_data is None:
        if not force:
            raise HTTPException(503)
        alert = notification_payloads.synthetic_example_alert(rule_type)
        return notification_payloads.example_alert_response(alert, force)

    notifiable_prices = notification_prices.get_notifiable_areas_prices(Box({profile.general.area: price_data}))
    example_prices = notifiable_prices.get(profile.general.area)
    use_example_data_copy = False
    if example_prices is None:
        if not force:
            return {"would_send": False}
        example_prices = notification_payloads.example_prices_from_available_data(price_data)
        use_example_data_copy = True

    if example_prices is None:
        alert = notification_payloads.synthetic_example_alert(rule_type)
        return notification_payloads.example_alert_response(alert, force)

    selected_prices = notification_payloads.selected_prices_for_rule(
        profile, rule_type, example_prices
    )
    if not selected_prices:
        if not force:
            return {"would_send": False}
        profile, selected_prices = notification_payloads.forced_example_for_rule(
            profile, rule_type, example_prices
        )

    if use_example_data_copy:
        alert = notification_payloads.synthetic_example_alert(rule_type)
        if rule_type == "price_below":
            best_price = min(selected_prices, key=lambda price_point: notification_payloads.adjusted_price(price_point, profile))
            alert["loc-args"] = [
                notification_payloads.stringify_adjusted_price(best_price, profile),
                notification_payloads.format_price_timestamp(best_price.start_timestamp, example_prices.data.resolution),
                notification_payloads.stringify_adjusted_price(best_price, profile),
            ]
        elif rule_type == "price_above":
            worst_price = max(selected_prices, key=lambda price_point: notification_payloads.adjusted_price(price_point, profile))
            alert["loc-args"] = [
                notification_payloads.stringify_adjusted_price(worst_price, profile),
                notification_payloads.format_price_timestamp(worst_price.start_timestamp, example_prices.data.resolution),
                notification_payloads.stringify_adjusted_price(worst_price, profile),
            ]
        elif rule_type == "daily_summary":
            best_price = min(example_prices.data.prices, key=lambda price_point: notification_payloads.adjusted_price(price_point, profile))
            worst_price = max(example_prices.data.prices, key=lambda price_point: notification_payloads.adjusted_price(price_point, profile))
            alert["loc-args"] = [
                notification_payloads.format_price_timestamp(best_price.start_timestamp, example_prices.data.resolution),
                notification_payloads.stringify_adjusted_price(best_price, profile),
                notification_payloads.format_price_timestamp(worst_price.start_timestamp, example_prices.data.resolution),
                notification_payloads.stringify_adjusted_price(worst_price, profile),
            ]
        return notification_payloads.example_alert_response(alert, force)

    notification = notification_payloads.construct_notification(profile, rule_type, selected_prices, example_prices)
    return notification_payloads.example_alert_response(notification.aps.alert, force)
