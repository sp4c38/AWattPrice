"""Handle the AWattPrice backend configurations."""
import sys

from pathlib import Path

from box import Box
from liteconfig import Config
from loguru import logger

from awattprice.defaults import DEFAULT_CONFIG

def transform_config(config: Config):
    """Transform certain config fields to another data type and/or value after they were read.

    Example: Transform path string into a pathlib Path instance.
    """
    config.paths.log = Path(config.paths.log).expanduser()


def get_config():
    """Read the config and setup localconfig's global config variable.

    To use the config import the global config variable from localconfig.
    """
    # First path in list will be used for creation if no config file exists yet.
    read_attempt_paths = [
        Path("~/.config/awattprice/config.ini").expanduser(),
        Path("/etc/awattprice/config.ini")
    ]
    config_path = None
    for possible_path in read_attempt_paths:
        if possible_path.is_file():
            config_path = possible_path
            break

    config = None
    if config_path:
        config = Config(config_path.as_posix())
    else:
        sys.stdout.write(f"No config file found. Creating at {config_path}...")
        config_path = read_attempt_paths[0]
        config_path.parent.mkdir(parents=True, exist_ok=True)
        with config_path.open("w") as config_file:
            config_file.write(DEFAULT_CONFIG)
        config = Config(DEFAULT_CONFIG)

    transform_config(config)
    return config


def configure_loguru(config: Config):
    """Configure loguru's logger."""
    log_dir_path = config.paths.log
    if log_dir_path.exists():
        if not log_dir_path.is_dir():
            sys.stderr.write(
                f"Directory used to store logs {log_dir_path.as_posix()} is a file, not a directory.\n"
            )
            sys.exit(1)
    else:
        sys.stdout.write(f"Log directory missing. Creating at {log_dir_path}.\n")
        log_dir_path.mkdir(parents=True, exist_ok=True)

    log_path = log_dir_path / "pizzaapp.log"
    logger.add(
        log_path,
        colorize=None,
        backtrace=True,
        diagnose=True if config.general.debug is True else False,
        rotation="1 week",
    )
