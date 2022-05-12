"""Read, store and set configurations.."""
import sys

from pathlib import Path
from typing import Optional
from typing import TypeVar

from liteconfig import Config
from loguru import logger

from awattprice import defaults

ConfigValue = TypeVar("ConfigValue")


def _check_config_none(config_value: ConfigValue) -> Optional[ConfigValue]:
    """Check if the value of the config attribute is empty and thus can be represented as pythons none object.

    :param config_value: The value of a single configuration attribute.
    :returns: If value isn't empty return config value. If value is empty return none to represent that
        the value isn't set.
    """
    if isinstance(config_value, str):
        no_spaces_config = config_value.replace(" ", "")
        if len(no_spaces_config) == 0:
            return None
    return config_value


def _transform_config(config: Config):
    """Transform certain config fields to another data type and/or value."""
    config.general.log_level = config.general.log_level.upper()

    config.paths.log_dir = Path(config.paths.log_dir).expanduser()
    config.paths.data_dir = Path(config.paths.data_dir).expanduser()
    config.paths.price_data_dir = config.paths.data_dir / defaults.PRICE_DATA_SUBDIR_NAME
    config.paths.apns_dir = Path(config.paths.apns_dir).expanduser()

    config.paths.old_database = _check_config_none(config.paths.old_database)
    if config.paths.old_database is not None:
        config.paths.old_database = Path(config.paths.old_database)


def _ensure_dir(path: Path):
    """Ensure that the dir at the parsed path is a directory and exists.

    If the directory doesn't exist create it.

    :raises NotADirectoryError: if the parsed path is anything but a directory.
    :returns: If this returns the path is a directory and it exists.
    """
    if not path.exists():
        sys.stdout.write(f"INFO: Creating missing directory referred to in the config: {path}.\n")
        path.mkdir(parents=True)

    if not path.is_dir():
        raise NotADirectoryError(path)


def _ensure_config_dirs(config: Config):
    """Ensure certain directories referred to in the config exist."""
    _ensure_dir(config.paths.log_dir)
    _ensure_dir(config.paths.data_dir)
    _ensure_dir(config.paths.price_data_dir)
    _ensure_dir(config.paths.apns_dir)


def get_config() -> Config:
    """Read and transform config and check some requirements."""
    # First path in list will be used for creation if no config file exists yet.
    read_attempt_paths = [
        Path("/etc/awattprice/config.ini"),
        Path("~/.config/awattprice/config.ini").expanduser(),
    ]
    config_path = None
    for possible_path in read_attempt_paths:
        if possible_path.is_file():
            config_path = possible_path
            break

    config = None
    if config_path:
        config = Config(str(config_path))
    else:
        sys.stdout.write(f"INFO: No config file found. Creating at {config_path}.\n")
        config_path = read_attempt_paths[0]
        config_path.parent.mkdir(parents=True, exist_ok=True)
        with config_path.open("w") as config_file:
            config_file.write(defaults.DEFAULT_CONFIG)
        config = Config(defaults.DEFAULT_CONFIG)

    _transform_config(config)
    _ensure_config_dirs(config)

    return config


def configure_loguru(service_name: str, config: Config):
    """Configure loguru's logger.

    :param service_name: Name of the service for which logging should be registered.
    """
    log_name = service_name + ".log"
    log_path = config.paths.log_dir / (service_name + ".log")
    logger.add(
        log_path,
        level=config.general.log_level,
        enqueue=True,  # This makes log calls non-blocking.
        colorize=True,
        backtrace=True,
        diagnose=config.general.staging,
        rotation="1 week",
    )
