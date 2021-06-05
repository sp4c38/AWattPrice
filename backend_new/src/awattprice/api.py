"""Api starting file which handles all url calls."""
from json import JSONDecodeError

from box import Box
from fastapi import FastAPI
from fastapi import HTTPException
from fastapi import Request
from loguru import logger
from starlette.responses import RedirectResponse

from awattprice import notifications
from awattprice import orm
from awattprice.config import configure_loguru
from awattprice.config import get_config
from awattprice.database import get_app_database
from awattprice.defaults import Region
from awattprice.prices import get_current_prices

config = get_config()
configure_loguru(config)

db_engine = get_app_database(config, async_engine=True)
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


@logger.catch
@app.post("/notifications/do_tasks/")
async def do_notification_tasks(request: Request):
    """Runs one or multiple notification setting update tasks for a token."""
    try:
        tasks_container_raw = Box(await request.json())
    except JSONDecodeError as exc:
        body_raw = await request.body()
        logger.warning(f"Couldn't decode notification tasks {body_raw} as json: {exc}.")
        raise HTTPException(400) from exc

    tasks_container = notifications.transform_tasks_body(tasks_container_raw)
    await notifications.run_notification_tasks(tasks_container)

    return None
