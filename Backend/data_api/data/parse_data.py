# Download and parse data from the different data sources

from django.conf import settings

import arrow
import configparser
import json
import requests

from data_api.data import merge_data

def parse_awattar_energy_prices(config):
    # Downloads and parses the energy prices

    # Prices for the next day are first avalible from 14 o'clock on of the current day


    awattar_raw_url = config["awattar"]["download_url"]
    awattar_data = {"prices": [], "min_price": None, "max_price": None}

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

            for price in json_response["data"]:
                if "Eur/MWh" in price["unit"]:
                    price["unit"] = ["Eur / MWh", "Eur / kWh"]
                    awattar_data["prices"].append(price)
                    if awattar_data["max_price"] == None or price["marketprice"] > awattar_data["max_price"]:
                        awattar_data["max_price"] = price["marketprice"]
                    elif awattar_data["min_price"] == None or price["marketprice"] < awattar_data["min_price"]:
                        awattar_data["min_price"] = price["marketprice"]

            return awattar_data
        except:
            print("Exception parsing JSON data returned from awattar.")
            return awattar_data
    else:
        print(f"Error downloading prices data from awattar. Request returned with status code: {data_request.status_code}")
        return awattar_data

def main():
    config_file_path = settings.BASE_DIR.joinpath("data_api", "data", "data_config.ini").as_posix()
    config = configparser.ConfigParser()
    config.read(config_file_path)

    # Download prices for today and for tomorrow (if there are already prices for tomorrow) for tomorrow day from the aWATTar API
    awattar_data = parse_awattar_energy_prices(config)

    return merge_data.main(awattar = awattar_data)

if __name__ == '__main__':
    main()
