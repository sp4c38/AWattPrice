# -*- coding: utf-8 -*-

"""Call the own Backend server.

Send a data GET request for all regions to the own backend to make it download and
cache new data and send notifications.
This script is meant to be called seperately in a specific time range each n seconds.
For example: Each 5 minutes throughout the whole day.
The script will check if the Backend would update its data. Only if this applies
it actually calls the Backend. This doesn't produce unnecessary trafic.

"""
__author__ = "Léon Becker <lb@space8.me>"
__copyright__ = "Léon Becker"
__license__ = "mit"

import asyncio
import filelock
import httpx
import json

import validators

from fastapi import status
from loguru import logger as log
from pathlib import Path
from urllib.parse import urlparse

from awattprice.config import read_config
from awattprice.defaults import Region
from awattprice.utils import check_data_needs_update, read_data, start_logging


async def send_request(url: str, client: httpx.AsyncClient, max_tries: int) -> bool:
    request_successful = False
    tries_made = 0
    while tries_made < max_tries and request_successful is False:
        tries_made += 1
        log.debug(f"Starting attempt {tries_made} for {url}.")

        try:
            response = await client.get(url, timeout=5)
        except httpx.ConnectTimeout:
            log.warning(f"Attempt {tries_made} to {url} timed out.")
        except httpx.ReadTimeout:
            log.warning(f"Attempt {tries_made} to {url} timed out.")
        except Exception as e:
            log.warning(f"Unrecognized exception at attempt {tries_made} for {url}: {e}.")
        else:
            if response.status_code == status.HTTP_200_OK:
                try:
                    json.loads(response.text)
                except json.JSONDecodeError as e:
                    log.warning(
                        f"Could not decode valid json of response (status code 200) from Backend: {e}")
                    request_successful = False
                except Exception as e:
                    log.warning(
                        f"Unknown exception while parsing response (status code 200) from Backend: {e}")
                    request_successful = False
                else:
                    request_successful = True
                    log.debug(f"Attempt {tries_made} to {url} was successful.")
            else:
                log.warning(
                    f"Server for {url} responded with status code other than 200.")
                request_successful = False

    if tries_made is max_tries:
        log.warning(f"Maximal attemps ({max_tries}) for {url} exhausted.")

    return request_successful


async def run_request(region, max_tries, config):
    need_update_region = True
    async with httpx.AsyncClient() as client:
        url = urlparse(config.poll.backend_url)
        url_path = Path("data") / region.name.upper()
        url = url._replace(path=url_path.as_posix()).geturl()

        region_file_path = Path(config.file_location.data_dir).expanduser() / Path(f"awattar-data-{region.name.lower()}.json")
        data = await read_data(file_path=region_file_path)
        if data:
            # Check if backend would update data. If not we can save resources and don't need to send the request.
            need_update_region = check_data_needs_update(data, config)

        if not need_update_region:
            log.debug(f"{region.name} data doesn't need to be requested. It is already up-to date.")
            return
        else:
            await send_request(url, client, max_tries)


async def main():
    config = read_config()
    start_logging(config)
    log.info("Started scheduled request.")

    if config.poll.backend_url:
        if validators.url(config.poll.backend_url) is True:
            lock_file_path = Path(
                config.file_location.data_dir).expanduser() / "scheduled_event.lck"

            scheduled_event_lock = filelock.FileLock(lock_file_path, timeout=5)

            try:
                with scheduled_event_lock.acquire():

                    tasks = []
                    for region in [[getattr(Region, "de".upper(), None), 3],  # number of attempts for a successful request, region id
                                   [getattr(Region, "at".upper(), None), 3]]:
                        if region[0].name is not None:
                            tasks.append(asyncio.create_task(
                                run_request(region[0], region[1], config)))

                    await asyncio.gather(*tasks)
            except filelock.Timeout:
                log.warning(
                    "Scheduled request lock still acquired. Won't run scheduled request.")
        else:
            log.warning(f"Value {config.poll.backend_url} set in \"config.poll.backend_url\" is no valid URL.")
    else:
        log.warning(
            """Scheduled request was called without having "config.poll.backend_url" configured. Won't run scheduled request.""")

    log.info("Finished scheduled request.")


if __name__ == "__main__":
    asyncio.run(main())
