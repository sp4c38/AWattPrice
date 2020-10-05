# Download and parse data from the different data sources

from django.conf import settings

import arrow
import configparser
import json
import requests

def parse_awattar_energy_prices(config):
    # Downloads and parses the energy prices

    # Prices for the next day are first avalible from 14 o'clock on of the current day


    awattar_raw_url = config["awattar"]["download_url"]
    awattar_data = {"prices": []}

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
                    # Only send marketprice results as Euro per MWh
                    price.pop("unit")
                    awattar_data["prices"].append(price)

            return awattar_data
        except:
            print("Exception parsing JSON data returned from awattar.")
            return awattar_data
    else:
        print(f"Error downloading prices data from awattar. Request returned with status code: {data_request.status_code}")
        return awattar_data

def main():
    config_file_path = settings.BASE_DIR.joinpath("energy_information", "awattar", "data_config.ini").as_posix()
    config = configparser.ConfigParser()
    config.read(config_file_path)

    # Download prices for today and for tomorrow (if there are already prices for tomorrow) for tomorrow day from the aWATTar API
    awattar_data = parse_awattar_energy_prices(config)

    return awattar_data

if __name__ == '__main__':
    main()
