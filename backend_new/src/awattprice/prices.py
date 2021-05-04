"""Poll and process price data."""
from box import Box

from awattprice.defaults import Region

async def poll_current_prices(region: Region) -> Box:
    pass

async def get_prices(region: Region) -> dict:
    return {}