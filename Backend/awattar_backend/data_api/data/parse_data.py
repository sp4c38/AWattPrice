# Download and parse data from the different data sources

from django.conf import settings

import arrow
import configparser
import requests

def download_arrow_source(config):
    awattar_raw_url = config["awattar"]["download_url"]
    # Use CET timezone to download the newest data from awattar
    params = {"start": "", "end": ""}
    # import IPython;IPython.embed();import sys;sys.exit()


def main():
    config_file_path = settings.BASE_DIR.joinpath("data_api", "data", "data_config.ini").as_posix()
    config = configparser.ConfigParser()
    config.read(config_file_path)

    # Download data from todays day from the aWATTar API
    arrow_data = download_arrow_source(config)

    return {"Data Raw Url": config["awattar"]["download_url"]}

if __name__ == '__main__':
    main()
