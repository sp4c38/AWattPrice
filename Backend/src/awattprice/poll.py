# -*- coding: utf-8 -*-

"""

Poll aWATTar data from their public API.

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

import asyncio

from pathlib import Path

import arrow  # type: ignore
import os
import uuid

from box import Box  # type: ignore
from filelock import FileLock
from loguru import logger as log
from typing import Dict, List, Optional, Tuple

from . import awattar
from .config import read_config
from .defaults import CONVERT_MWH_KWH, Region, TIME_CORRECT
from .utils import (
    start_logging,
    read_data,
    write_data,
    async_acquire_lock,
    check_data_needs_update,
)


def transform_entry(entry: Box) -> Optional[Box]:
    """Return the data entry as the AWattPrice app expects it."""
    try:
        if entry.unit == "Eur/MWh":
            entry.pop("unit")
            # Divide through 1000 to not display miliseconds
            entry.start_timestamp = int(entry.start_timestamp / TIME_CORRECT)
            entry.end_timestamp = int(entry.end_timestamp / TIME_CORRECT)
            # Convert MWh to kWh
            entry.marketprice = round(entry.marketprice * CONVERT_MWH_KWH, 2)
    except KeyError:
        log.warning(f"Missing key in Awattar entry. Skipping: {entry}.")
    except Exception as e:
        log.warning(f"Bogus data in Awattar entry. Skipping: {entry}: {e}")
    else:
        return entry
    return None


async def awattar_read_task(
    *,
    config: Box,
    region: Region,
    start: Optional[int] = None,
    end: Optional[int] = None,
) -> Optional[List[Box]]:
    """Async worker to read the Awattar data. If too old, poll the
    Awattar API.
    """
    try:
        data = await awattar.get(config=config, region=region, start=start, end=end)
    except Exception as e:
        log.warning(f"Error in Awattar data poller: {e}")
    else:
        return data
    return None


async def verify_awattar_not_polled(updating_lock: FileLock):
    # Verify that awattar is currently not polled by a other task.
    no_request_running = False
    while no_request_running is False:
        try:
            # Will raise exception if it can't acquire the lock immediately
            await async_acquire_lock(updating_lock, 0.001)
            no_request_running = True
        except Exception:
            # Currently a other task is polling the aWATTar API.
            # In this case wait until the other task completes to use the downloaded
            # data from that task. This avoids multiple requests initiated at about the same time
            # to poll aWATTar data multiple times instead of waiting for one polling task to complete.
            await asyncio.sleep(3)
    return True


async def get_data(config: Box, region: Optional[Region] = None, force: bool = False) -> Tuple[Optional[Box], bool]:
    """Request the Awattar data. Read it from file, if it is too old fetch it
    from the Awattar API endpoint.

    :param config: AWattPrice config
    :param force: Enforce fetching of data
    """
    if region is None:
        region = Region.DE

    file_path = Path(config.file_location.data_dir).expanduser() / Path(f"awattar-data-{region.name.lower()}.json")

    # If data directory doesn't exist create it.
    # This is also checked again when writing to the actual data file (if awattar data needs to be updated).
    check_dir = file_path.parent.expanduser()
    if not check_dir.is_dir():
        log.warning(f"Creating the data destination directory {check_dir}.")
        os.makedirs(check_dir.as_posix())
    updating_lock_path = check_dir / Path(f"updating-{region.name.lower()}-data.lck")
    updating_lock = FileLock(updating_lock_path.as_posix())
    await verify_awattar_not_polled(updating_lock)
    data = await read_data(file_path=file_path)

    fetched_data = None
    need_update = True
    check_notification = False  # If no cached data exists this value will stay False
    # and won't trigger any notification updates.
    # Notification updates are only run when cached data already exists.
    now = arrow.utcnow()
    if data:
        need_update = check_data_needs_update(data, config)

    if need_update or force:
        # By default the Awattar API returns data for the next 24h. It can provide
        # data until tomorrow midnight. Let's ask for that. Further, set the start
        # time to the last full hour. The Awattar API expects microsecond timestamps.
        start = now.replace(minute=0, second=0, microsecond=0).timestamp * TIME_CORRECT
        end = now.shift(days=+2).replace(hour=0, minute=0, second=0, microsecond=0).timestamp * TIME_CORRECT

        future = awattar_read_task(config=config, region=region, start=start, end=end)
        results = await asyncio.gather(*[future])

        if results is None:
            return None, False
        if results:
            log.info(f"Successfully fetched fresh data from aWATTar for {region.name} region.")
            # We run one task in asyncio
            fetched_data = results.pop()
        else:
            log.info("Failed to fetch fresh data from aWATTar.")
            fetched_data = None
    else:
        updating_lock.release()
        log.debug(f"No need to update aWATTar data for region {region.name} from their API.")

    # Update existing data
    must_write_data = False
    if data and fetched_data:
        max_existing_data_start_timestamp = max([d.start_timestamp for d in data.prices]) * TIME_CORRECT
        for entry in fetched_data:
            ts = entry.start_timestamp
            if ts <= max_existing_data_start_timestamp:
                continue
            entry = transform_entry(entry)
            if entry:
                check_notification = True
                data.prices.append(entry)

        # Must always equal True if new data was fetched to update update_ts to newest value.
        must_write_data = True
        data.meta.update_ts = now.timestamp
        new_uuid = uuid.uuid4().hex
        while new_uuid == data.meta.uuid:
            new_uuid = uuid.uuid4().hex
        data.meta.uuid = new_uuid
    elif fetched_data:
        data = Box({"prices": [], "meta": {}}, box_dots=True)
        data.meta["update_ts"] = now.timestamp
        data.meta["uuid"] = uuid.uuid4().hex
        for entry in fetched_data:
            entry = transform_entry(entry)
            if entry:
                must_write_data = True
                data.prices.append(entry)

    # Filter out data older than 24h and write to disk
    if must_write_data:
        log.info("Writing Awattar data to disk.")
        before_24h = now.shift(hours=-24).timestamp
        data.prices = [e for e in data.prices if e.end_timestamp > before_24h]
        await write_data(data=data, file_path=file_path)
        if need_update or force:
            updating_lock.release()
    else:
        updating_lock.release()
    # As the last resort return empty data.
    if not data:
        data = Box({"prices": []})
    return data, check_notification


async def get_headers(config: Box, data: Box) -> Dict:
    data = Box(data)
    headers = {"Cache-Control": "private, max-age={}"}
    max_age = 0

    now = arrow.utcnow()
    price_points_in_future = 0
    for price_point in data.prices:
        if price_point.start_timestamp > now.timestamp:
            price_points_in_future += 1

    if price_points_in_future < int(config.poll.if_less_than):
        # Runs when the data is fetched at every call (respecting minimum time interval between updates)
        # and the aWATTar data will probably update soon.
        if int(config.poll.awattar) <= 300:
            max_age = 300
        else:
            max_age = config.poll.awattar
    else:
        if (price_points_in_future - int(config.poll.if_less_than)) == 0:
            # Runs when it is currently the hour before the backend
            # will continuously look for new price data.
            # max_age is set so that the client only caches until the backend
            # will start continuous requesting for new price data.
            next_hour_start = now.replace(hour=now.hour + 1, minute=0, second=0, microsecond=0)
            difference = next_hour_start - now
            max_age = difference.seconds
        else:
            # Runs on default when server doesn't continuously look for new price data.
            # and it isn't the hour before continouse updating will occur.
            max_age = 900

    headers["Cache-Control"] = headers["Cache-Control"].format(max_age)
    return headers


def main() -> Box:
    """Entry point for the data poller."""
    config = read_config()
    start_logging(config)
    data = get_data(config)
    return data


if __name__ == "__main__":
    main()
