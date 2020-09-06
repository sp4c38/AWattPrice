# Download and parse data from the different data sources

from django.conf import settings

import arrow
import configparser
import json
import requests

def download_awattar_energy_prices(config):
    # Downloads the price for energy in the time range:
    # If current time is before 14'clock: 14 o'clock of the previouse day to 14 o'clock of current day
    # If current time is after 14'clock : 14 o'clock of the previouse day to 14 o'clock of tomorrow

    # Prices for the next day are first avalible from 14 o'clock of the current day

    awattar_raw_url = config["awattar"]["download_url"]

    # Use CET timezone to download the newest data from awattar
    cet_now = arrow.utcnow().to("CET") # Current time

    first_cet_timestamp = cet_now.replace(hour = 0, minute = 0, second = 0, microsecond = 0) # CET Today at midnight

    if cet_now.hour >= 14:
        # New prices are already avalible for next day
        second_cet_timestamp = first_cet_timestamp.shift(hours = +48)
    else:
        # New prices for next day aren't yet avalible
        second_cet_timestamp = first_cet_timestamp.shift(hours = +24)

    params = {"start": first_cet_timestamp.timestamp * 1000, "end": second_cet_timestamp.timestamp * 1000}
    data_request = requests.get(awattar_raw_url, params = params)

    if data_request.ok:
        try:
            json_response = data_request = json.loads(data_request.text)
            return json_response
        except:
            print("Exception parsing JSON data returned from awattar.")
            return {}
    else:
        print(f"Error downloading prices data from awattar. Request returned with status code: {data_request.status_code}")
        return {}

def main():
    config_file_path = settings.BASE_DIR.joinpath("data_api", "data", "data_config.ini").as_posix()
    config = configparser.ConfigParser()
    config.read(config_file_path)

    # Download prices for today and for tomorrow (if there are already prices for tomorrow) for tomorrow day from the aWATTar API
    arrow_data = download_awattar_energy_prices(config)

    return {"Arrow Data": arrow_data}

if __name__ == '__main__':
    main()
