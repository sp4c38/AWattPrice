"""Api starting file which handles all url calls."""
from json import JSONDecodeError

import arrow

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
from awattprice.database import get_async_engine
from awattprice.defaults import Region
from awattprice.prices import get_current_prices

config = get_config()
configure_loguru(config)

db_engine = get_async_engine(config)
orm.metadata.bind = db_engine

app = FastAPI()


@logger.catch
@app.get("/data/{region}")
async def get_region_data(region: Region):
    """Get current price data for specified region."""
    price_data = await get_current_prices(region, config)
    return price_data


@logger.catch
@app.get("/data/")
async def get_default_region_data():
    """Get current price data for default region.

    This will respond with an temporary redirect to the data price site of the default region.
    """
    region = Region.DE
    return RedirectResponse(url=f"/data/{region.value}")


@logger.catch
@app.post("/notifications/run_tasks/")
async def do_notification_tasks(request: Request):
    """Runs one or multiple notification setting update tasks for a token."""
    try:
        body_json = await request.json()
    except JSONDecodeError as exc:
        body_raw = await request.body()
        logger.warning(f"Couldn't decode notification tasks {repr(body_raw)} as json: {exc}.")
        raise HTTPException(400) from exc

    tasks_packed_raw = Box(body_json)
    tasks_packed = notifications.transform_tasks_body(tasks_raw)

    token_hex = tasks_packed.token
    tasks = tasks_packed.tasks
    await notifications.run_notification_tasks(token_hex, tasks)


# Old /data/apns/send_token/ url should be supported by the old backend for backwards-compatibility reasons.