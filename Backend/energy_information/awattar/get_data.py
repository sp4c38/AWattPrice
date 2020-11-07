# Download and parse data from the different data sources

from django.conf import settings
from django.http import JsonResponse

import configparser
import json
import os

def get_data(request):
    # Gets the current cached data

    config_file_path = settings.BASE_DIR.joinpath("energy_information", "awattar", "data_config.ini").as_posix()
    config = configparser.ConfigParser()
    config.read(config_file_path)
    store_file_path = os.path.expanduser(config["store"]["store_file_path"])

    newest_data = json.load(open(store_file_path))

    return JsonResponse(newest_data)

if __name__ == '__main__':
    main()
