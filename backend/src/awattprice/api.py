"""Define the urls and their tasks handled by the API."""
import sys

from json import JSONDecodeError

import arrow

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
from awattprice.defaults import Region

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
@app.get("/data/{region}")
async def get_region_data(region: Region):
    """Get current price data for specified region."""
    price_data = await prices.get_current_prices(region, config, fall_back=True)

    if price_data is None:
        logger.warning(f"Couldn't get current price data for region {region.name}.")
        raise HTTPException(503)

    response_price_data = prices.parse_to_response_data(price_data)

    return response_price_data


@logger.catch
@app.get("/data/")
async def get_default_region_data():
    """Get current price data for default region.

    This will respond with an temporary redirect to the data price site of the default region.
    """
    region = Region.DE
    return RedirectResponse(url=f"/data/{region.value}")


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
