# -*- coding: utf-8 -*-

"""

AWattPrice API module

Poll the Awattar API
"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

from typing import Any, Dict, List, Optional, Union

from fastapi import BackgroundTasks, FastAPI, Request
from fastapi.responses import JSONResponse

from awattprice import poll, apns
from awattprice.config import read_config
from awattprice.defaults import Region
from awattprice.token_manager import Token_Database_Manager
from awattprice.utils import start_logging

api = FastAPI()
config = read_config()
start_logging(config)

db_manager = Token_Database_Manager()
db_manager.connect(config)
db_manager.check_table_exists()

@api.get("/")
async def root():
    return {"message": "Nothing here. Please, move on."}


@api.get("/data/")
async def no_region():
    """Return data if no region is given for Germany."""
    config = read_config()
    region = Region.DE
    data = await poll.get_data(config=config, region=region)
    headers = await poll.get_headers(config=config, data=data)
    return JSONResponse(content=data, headers=headers)


@api.get("/data/{region_id}")
async def with_region(region_id):
    """Return data for the given region."""
    config = read_config()
    region = getattr(Region, region_id.upper(), None)
    if not region:
        return {"prices": []}
    data = await poll.get_data(config=config, region=region)
    headers = await poll.get_headers(config=config, data=data)
    return JSONResponse(content=data, headers=headers)

@api.post("/data/apns/send_token")
async def send_token(request: Request, background_tasks: BackgroundTasks):
    token = await apns.validate_token(request)
    if not token == None:
        background_tasks.add_task(apns.write_token, token, db_manager)
        return JSONResponse({"tokenWasPassedSuccessfully": True})
    else:
        return JSONResponse({"tokenWasPassedSuccessfully": False})

@api.on_event("shutdown")
def shutdown_backend():
    db_manager.disconnect()
