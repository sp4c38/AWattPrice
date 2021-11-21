# -*- coding: utf-8 -*-

"""

AWattPrice API module

Poll the Awattar API
"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"


from fastapi import BackgroundTasks, FastAPI, Request, status
from fastapi.responses import JSONResponse

from awattprice import apns, poll
from awattprice.config import read_config
from awattprice.defaults import Region
from awattprice.types import APNSToken
from awattprice.utils import start_logging

api = FastAPI()


@api.get("/")
async def root():
    return {"message": "Nothing here. Please, move on."}


@api.get("/data/")
async def no_region(background_tasks: BackgroundTasks):
    """Return data if no region is given for Germany."""
    region = Region.DE
    data, _ = await poll.get_data(config=config, region=region)

    headers = await poll.get_headers(config=config, data=data)
    return JSONResponse(content=data, headers=headers)


@api.get("/data/{region_id}")
async def with_region(region_id, background_tasks: BackgroundTasks):
    """Return data for the given region."""
    region = getattr(Region, region_id.upper(), None)
    if not region:
        return {"prices": []}
    data, _ = await poll.get_data(config=config, region=region)

    headers = await poll.get_headers(config=config, data=data)
    return JSONResponse(content=data, headers=headers)


@api.post("/data/apns/send_token")
async def send_token(request: Request, background_tasks: BackgroundTasks):
    request_body = await request.body()
    request_data: APNSToken = apns.validate_token(request_body)
    if request_data is not None:
        background_tasks.add_task(apns.write_token, request_data)
        return JSONResponse({"tokenWasPassedSuccessfully": True}, status_code=status.HTTP_200_OK)
    else:
        return JSONResponse(
            {"tokenWasPassedSuccessfully": False},
            status_code=status.HTTP_400_BAD_REQUEST,
        )


@api.on_event("startup")
def startup_event():
    global config
    config = read_config()
    start_logging(config)