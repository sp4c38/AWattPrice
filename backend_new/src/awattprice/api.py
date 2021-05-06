"""Handle url calls to this web app."""
import uvicorn

from box import Box
from fastapi import FastAPI
from starlette.responses import RedirectResponse

from loguru import logger

from awattprice import config as conf
from awattprice.defaults import Region
from awattprice.prices import get_prices

config = conf.get_config()
conf.configure_loguru(config)
app = FastAPI()


@app.get("/data/{region}")
async def get_region_data(region: Region):
    """Get current price data for the specified region."""
    price_data = await get_prices(region)
    return {"region": region, "prices": price_data}

@app.get("/data/")
async def get_default_region_data():
    """Get current price data for a default region."""
    region = Region.DE
    return RedirectResponse(url=f"/data/{region.name}")

if __name__ == "__main__":
    uvicorn.run("api:app", host="127.0.0.1", port=8000, reload=True)