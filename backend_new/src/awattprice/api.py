"""Handle url calls to this web app."""
import uvicorn

from box import Box
from fastapi import FastAPI
from starlette.responses import RedirectResponse

from loguru import logger

from awattprice.config import configure_loguru, make_config
from awattprice.defaults import Region
from awattprice.prices import get_prices

make_config()
configure_loguru()
app = FastAPI()


@app.get("/data/{region}")
async def get_region_data(region: Region):
    """Get current price data for the specified region."""
    price_data = await get_prices(region)
    return {"region": region, "prices": price_data}

@app.get("/data/")
async def get_default_region_data():
    """Get current price data for a default region."""
    logger.debug("Test")
    region = Region.DE
    return RedirectResponse(url=f"/data/{region.name}")

if __name__ == "__main__":
    uvicorn.run("api:app", host="127.0.0.1", port=8000, reload=True)