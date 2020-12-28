import json

from awattprice import poll
from awattprice.defaults import Region

from loguru import logger as log


async def check_and_send(config, data, data_region, db_manager):
    log.info("Checking and sending notifications.")
    log.debug(f"Need to check and send notifications for data region {data_region.name}.")
    # Get all other regions and get their region data
    region_dir = dir(Region)
    other_regions = []
    for attr in region_dir:
        if not "__" in attr and not attr == data_region.name:
            other_regions.append(getattr(Region, attr.upper(), None))

    all_data = {}
    for region in other_regions:
        region_data, region_check_notification = await poll.get_data(config=config, region=region)
        region_check_notification = True
        if region_check_notification:
            log.debug(f"Need to check and send notifications for data region {region.name}.")
            all_data[region.value] = {"data": region_data}

    all_data[data_region.value] = {"data": data}
    del data

    await db_manager.acquire_lock()
    cursor = db_manager.db.cursor()
    items = cursor.execute("SELECT * FROM token_storage;").fetchall()
    items = [dict(x) for x in items]

    log.debug("Checking all stored notification configurations if they apply to receive a notification.")
    for notifi_config in items:
        if notifi_config["region_identifier"] in all_data: # Check if client is in region which
                                                           # applies for notification updates
            token = notifi_config["token"]
            try:
                configuration = json.loads(notifi_config["configuration"])["config"]
            except:
                log.warning("Internally passed notification configuration of a client couldn't be read "\
                            "when checking if he should receive notifications.")

            if configuration["price_below_value_notification"]["active"] == True:
                pass


    await db_manager.release_lock()
