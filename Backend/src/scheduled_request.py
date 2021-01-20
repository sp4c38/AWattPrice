# -*- coding: utf-8 -*-

"""Call the own Backend server.

Send a data GET request for all regions to the own backend to make it download and
cache new data and send notifications.
This script is meant to be called separately in a specific time range each n seconds.
For example: Each 5 minutes throughout the whole day.
The script will check if the Backend would update its data. Only if this applies
it actually calls the Backend. This doesn't produce unnecessary trafic.

"""
__author__ = "Léon Becker <lb@space8.me>"
__copyright__ = "Léon Becker"
__license__ = "mit"

import asyncio
import json
import os

from pathlib import Path
from urllib.parse import urlparse

import filelock
import httpx
import validators

from fastapi import status
from loguru import logger as log
from tenacity import retry, stop_after_attempt, stop_after_delay, wait_exponential  # type: ignore

from awattprice.config import read_config
from awattprice.defaults import Region
from awattprice.utils import before_log, check_data_needs_update, read_data, start_logging


@retry(
    before=before_log(log, "debug"),
    stop=(stop_after_delay(60) | stop_after_attempt(8)),
    wait=wait_exponential(multiplier=1, min=4, max=10),
    reraise=True,
)
async def send_request(url: str, client: httpx.AsyncClient) -> bool:
    """Send a HTTP GET request."""
    request_successful = False
    log.debug(f"Starting HTTP GET request to {url}.")
    try:
        response = await client.get(url, timeout=5)
    except httpx.ConnectTimeout:
        log.warning(f"Connect attempt to {url} timed out.")
        raise
    except httpx.ReadTimeout:
        log.warning(f"Attempt to {url} timed out.")
        raise
    except Exception as e:
        log.warning(f"Unrecognized exception at attempt for {url}: {e}.")
        raise
    else:
        if response.status_code == status.HTTP_200_OK:
            try:
                json.loads(response.text)
            except json.JSONDecodeError as e:
                log.warning(f"Could not decode valid JSON of response (status code 200) from Backend: {e}")
                raise
            except Exception as e:
                log.warning(f"Unknown exception while parsing response (status code 200) from Backend: {e}")
                raise
            else:
                log.debug(f"HTTP GET to {url} was successful.")
        else:
            log.warning(f"Server for {url} responded with status code other than 200.")
            response.raise_for_status()

    return request_successful


async def run_request(region, config):
    need_update_region = True
    async with httpx.AsyncClient() as client:
        url = urlparse(config.poll.backend_url)
        url_path = Path("data") / region.name
        url = url._replace(path=url_path.as_posix()).geturl()

        region_file_path = Path(config.file_location.data_dir).expanduser() / Path(
            f"awattar-data-{region.name.lower()}.json"
        )
        data = await read_data(file_path=region_file_path)
        if data:
            # Check if backend would update data. If not we can save resources and don't need to send the request.
            need_update_region = check_data_needs_update(data, config)

        if not need_update_region:
            log.debug(f"{region.name} data doesn't need to be requested. It is already up-to date.")
            return
        else:
            await send_request(url, client)


async def main():
    config = read_config()
    start_logging(config, for_scheduled_request=True)
    log.info("Started a scheduled request.")

    if config.poll.backend_url:
        if validators.url(config.poll.backend_url) is True:
            lock_file_path = Path(config.file_location.data_dir).expanduser() / Path("scheduled_event.lck")
            if not lock_file_path.parent.is_dir():
                os.makedirs(lock_file_path.parent.as_posix())
            scheduled_event_lock = filelock.FileLock(lock_file_path, timeout=5)

            try:
                with scheduled_event_lock.acquire():
                    tasks = []
                    for region in [Region.DE, Region.AT]:
                        tasks.append(asyncio.create_task(run_request(region, config)))
                    await asyncio.gather(*tasks)
            except filelock.Timeout:
                log.warning("Could not acquire the request lock. Won't run scheduled request.")
        else:
            log.warning(f'Value {config.poll.backend_url} set in "config.poll.backend_url" is no valid URL.')
    else:
        log.warning(
            """Scheduled request was called without having "config.poll.backend_url" configured. Won't run scheduled request."""
        )

    log.info("Finished a scheduled request.\n")  # leave a little space for the next run


if __name__ == "__main__":
    asyncio.run(main())
