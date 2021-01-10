# -*- coding: utf-8 -*-

"""

Awattar module

Poll the Awattar API
"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

from typing import Any, Dict, List, Optional
from urllib.parse import urlencode

import arrow  # type: ignore
import httpx

from box import Box, BoxList  # type: ignore
from loguru import logger as log
from tenacity import retry, stop_after_attempt, stop_after_delay, wait_exponential  # type: ignore

from .defaults import Region
from .utils import before_log


async def get(
    *,
    config: Box,
    region: Region,
    start: Optional[int] = None,
    end: Optional[int] = None,
) -> Optional[List[Any]]:
    """Fetch and write Awattar data."""
    start_ts = arrow.utcnow()
    try:
        data = await get_data(config=config, region=region, start=start, end=end)
    except Exception as e:
        log.warning("Could not fetch Awattar data: {}.".format(str(e)))
    else:
        elapsed_time = arrow.utcnow() - start_ts
        log.debug(f"Fetching Awattar data took {elapsed_time.total_seconds():.3f} s.")
        return BoxList(data["data"])
    return None


@retry(
    before=before_log(log, "debug"),
    stop=(stop_after_delay(10) | stop_after_attempt(5)),
    wait=wait_exponential(multiplier=1, min=4, max=10),
    reraise=True,
)
async def get_data(
    *,
    config: Box,
    region: Region,
    start: Optional[int] = None,
    end: Optional[int] = None,
) -> Dict[Any, Any]:
    """Return a new consumer token."""
    lookup = f"awattar.{region.name.lower()}"
    awattar_config = config[lookup]
    endpoint = f"{awattar_config.host}{awattar_config.url}" + "{}"
    params = {}
    if start:
        params["start"] = str(start)
    if end:
        params["end"] = str(end)
    if params:
        url = endpoint.format("?" + urlencode(params))
    else:
        url = endpoint.format("")
    timeout = 10.0

    log.debug(f"Awattar URL: {url}")
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=timeout)
    except Exception as e:
        log.error(f"Caught an exception while fetching data from the Awattar API: {e}")
        raise
    try:
        data = response.json()
    except Exception as e:
        log.error(f"Could not JSON decode the Awattar response: {e}")
        raise

    return data
