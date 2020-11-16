# -*- coding: utf-8 -*-

"""

AWattPrice API module

Poll the Awattar API
"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

from typing import Any, Dict, List, Optional, Union

from fastapi import FastAPI

from awattprice import poll
from awattprice.config import read_config
from awattprice.defaults import Region
from awattprice.utils import start_logging


api = FastAPI()


@api.get("/")
async def root():
    return {"message": "Nothing here. Please, move on."}


@api.get("/data/")
async def no_region():
    """Return data if no region is given for Germany."""
    config = read_config()
    start_logging(config)
    region = Region.DE
    data = await poll.get_data(config=config, region=region)
    return data


@api.get("/data/{region_id}")
async def with_region(region_id):
    """Return data for the given region."""
    config = read_config()
    start_logging(config)
    region = getattr(Region, region_id.upper(), None)
    if not region:
        return {"prices": []}
    data = await poll.get_data(config=config, region=region)
    return data
