"""Main entry for this web application."""
from box import Box
from fastapi import FastAPI

from awattprice_backend.defaults import Region

app = FastAPI()


@app.get("/data/{region}")
async def get_region_data(region: Region):
    return {"region": region}