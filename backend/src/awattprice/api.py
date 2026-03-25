"""Define the urls and their tasks handled by the API."""
import sys

from json import JSONDecodeError

from box import Box
from fastapi import FastAPI
from fastapi import HTTPException
from fastapi import Request
from loguru import logger
from starlette.responses import RedirectResponse

from awattprice import configurator
from awattprice import database
from awattprice import defaults
from awattprice import notifications
from awattprice import orm
from awattprice import prices

config = configurator.get_config()
configurator.configure_loguru(defaults.AWATTPRICE_SERVICE_NAME, config)

try:
    database_engine = database.get_awattprice_engine(config, async_=True)
except FileNotFoundError as exc:
    logger.exception(exc)
    sys.exit(1)
orm.metadata.bind = database_engine

# Uncomment to create all database tables inside the database. An empty sqlite database must already exist and async_ must be set to false upon engine creation. 
# orm.Base.metadata.create_all()

app = FastAPI()


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
        defaults.get_market_area(normalized_area_key)
    except KeyError:
        raise HTTPException(404)

    price_data = await prices.get_current_prices(
        normalized_area_key,
        config,
        fall_back=True,
        background_refresh=True,
    )

    if price_data is None:
        logger.warning(f"Couldn't get current price data for area {normalized_area_key}.")
        raise HTTPException(503)

    response_price_data = prices.parse_to_response_data(price_data)

    return response_price_data


@logger.catch
@app.get("/prices/")
async def get_default_area_prices():
    """Get current price data for the default market area.

    This will respond with a temporary redirect to the default market area price endpoint.
    """
    return RedirectResponse(url=f"/prices/{defaults.DEFAULT_MARKET_AREA_KEY}")


@logger.catch
@app.post("/notifications/save_configuration/")
async def handle_notification_configuration(request: Request):
    """Runs one or multiple notification setting update tasks for a token."""
    try:
        body_json = await request.json()
    except JSONDecodeError as exc:
        body_raw = await request.body()
        logger.warning(f"Couldn't decode notification tasks {repr(body_raw)} as json: {exc}.")
        raise HTTPException(400)

    raw_configuration = Box(body_json)

    configuration = notifications.parse_notification_configuration_body(raw_configuration)
    if configuration is None:
        raise HTTPException(400)

    await notifications.save_notification_configuration(database_engine, configuration)
