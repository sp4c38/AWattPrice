import aiofiles
import arrow
import asyncio
import filelock
import httpx
import json

from loguru import logger as log
from pathlib import Path

from awattprice.config import read_config
from awattprice.utils import start_logging

async def request_data(queue, config):
    max_attempt_number = 2

    async with httpx.AsyncClient() as client:
        while not queue.empty():
            work_item = await queue.get()
            tried_attempts = work_item[0]
            if not tried_attempts > max_attempt_number:
                region_identifier = work_item[1]

                url = f"https://test-awp.space8.me/data/{region_identifier}"
                data_file_path = Path(config.file_location.data_dir).expanduser()
                data_file_path /= Path(f"awattar-data-{region_identifier.lower()}.json")
                if data_file_path.is_file():
                    data_file_lock = filelock.FileLock(f"{data_file_path.as_posix()}.lck", timeout=20)
                try:
                    data = None
                    if data_file_path.is_file():
                        with data_file_lock.acquire():
                            async with aiofiles.open(data_file_path, "r") as afp:
                                raw_json = await afp.read()
                                try:
                                    data = json.loads(raw_json)
                                    data["prices"]
                                except Exception as exp:
                                    log.warning(f"Tried to decode data in {data_file_path} but it is no "\
                                                  "valid json.")

                    now = arrow.now()
                    items_in_future = len([True for e in data["prices"] if e["start_timestamp"] > now.timestamp])
                    if items_in_future < int(config.poll.if_less_than):
                        int(config.poll.if_less_than)
                        try:
                            log.info(f"Starting attempt {tried_attempts} for {url}")
                            response = await client.get(url, timeout=5)
                            try:
                                json.loads(response.text)
                                log.info(f"Attempt {tried_attempts} was successful for {url}.")
                            except Exception as err:
                                log.warning(f"Couldn't decode response from attempt {tried_attempts} for"\
                                            f"{url}: {err}")
                                work_item[0] += 1
                                await queue.put(work_item)

                        except httpx.ConnectTimeout:
                            log.warning(f"Attempt {tried_attempts} for {url} timed out.")
                            work_item[0] += 1
                            await queue.put(work_item)
                    else:
                        log.info("Don't need to send scheduled request to AWattPrice "\
                                 f"backend for url {url} because in the cached data "\
                                 f"there are more future price points than {config.poll.if_less_than} "\
                                  "(number specified in settings for AWattPrice backend).")

                except filelock.Timeout:
                    work_item[0] += 1
                    await queue.put(work_item)
                    log.warning(f"Couldn't acquire lock for {data_file_path} data file associated "\
                                 f"with url {url}")
            else:
                log.warning(f"All possible attempts for {url} are exhausted.")

async def main():
    # Scheduled requests are called in certain time ranges in certain intervals
    # by a service like cron. This script calls the AWattPrice backend just like
    # a client would do. This is done especially to have up to date caches with
    # up to date data. This is also needed to frequently check if notifications
    # need and should be sent (e.g. send notification when price drops below
    # certain value -> need up to date data)
    # Therefor this script calls the AWattPrice backend because it handles
    # notification sending.

    config = read_config()
    start_logging(config)
    log.info("Started a scheduled request.")

    lock_file_path = Path(config.file_location.data_dir).expanduser() / "scheduled_event.lck"
    scheduled_event_lock = filelock.FileLock(lock_file_path, timeout=20)

    try:
        with scheduled_event_lock.acquire():
            queue = asyncio.Queue()
            for url in [[1, "DE"], # 1: number of attempts to poll this url.
                        [1, "AT"]]:
                        await queue.put(url)

            await asyncio.gather(
                asyncio.create_task(request_data(queue, config)),
                asyncio.create_task(request_data(queue, config)),
            )
    except filelock.Timeout:
        log.warning("Scheduled request couldn't acquire lock (timed out). Other scheduled "\
                    "request is currently running.")

    log.info("Finished a scheduled request.")

if __name__ == "__main__":
    asyncio.run(main())
