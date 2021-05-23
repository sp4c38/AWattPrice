"""Handle url calls to this web app."""
from json import JSONDecodeError

from box import Box
from fastapi import FastAPI, HTTPException, Request
from loguru import logger
from starlette.responses import RedirectResponse

from awattprice import notifications, orm
from awattprice.config import configure_loguru, get_config
from awattprice.database import get_app_database
from awattprice.defaults import Region
from awattprice.prices import get_current_prices

config = get_config()
configure_loguru(config)

db_engine = get_app_database(config)
orm.metadata.bind = db_engine

app = FastAPI()


@app.get("/data/{region}")
async def get_region_data(region: Region):
    """Get current price data for specified region."""
    price_data = await get_current_prices(region, config)
    return price_data


@app.get("/data/")
async def get_default_region_data():
    """Get current price data for default region.

    This will respond with an temporary redirect to the data price site of the default region.
    """
    region = Region.DE
    return RedirectResponse(url=f"/data/{region.value}")


@app.post("/notifications/do_tasks/")
async def do_notification_tasks(request: Request):
    """Runs one or multiple notification setting update tasks for a token."""
    try:
        body = Box(await request.json())
    except JSONDecodeError as exp:
        body_raw = await request.body()
        logger.info(f"Couldn't decode notification tasks {body_raw} as json: {exp}.")
        raise HTTPException(400) from exp

    tasks = notifications.get_body_tasks(body)

    return None
