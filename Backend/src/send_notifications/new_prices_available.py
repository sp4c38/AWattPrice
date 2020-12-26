import asyncio

from loguru import logger as log

from awattprice.config import read_config
from awattprice.utils import start_logging

def main():
    config = read_config()
    start_logging(config)


if __name__ == "__main__":
    main()
