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


def _is_missing_config_value(config_value: ConfigValue) -> bool:
    """Check whether liteconfig returned a missing-value placeholder."""
    return config_value.__class__.__name__ == "Nothing"


def _is_empty_or_missing_config_value(config_value: ConfigValue) -> bool:
    """Check whether a config value is missing or empty."""
    return _is_missing_config_value(config_value) or _check_config_none(config_value) is None


def _coerce_bool(config_value: ConfigValue) -> bool:
    """Coerce common config boolean representations to a bool."""
    if isinstance(config_value, bool):
        return config_value
    if _is_empty_or_missing_config_value(config_value):
        return False
    return str(config_value).strip().lower() in ("1", "true", "yes", "on")


def _fill_missing_config_values(config: Config):
    """Fill missing config values with the defaults shipped by the backend."""
    default_config = Config(defaults.DEFAULT_CONFIG)

    for section_name in ("general", "entsoe", "paths", "apns", "cronitor"):
        current_section = getattr(config, section_name)
        default_section = getattr(default_config, section_name)

        if _is_missing_config_value(current_section):
            setattr(config, section_name, default_section)
            continue

        for property_name, default_value in vars(default_section).items():
            if property_name.startswith("_"):
                continue

            current_value = getattr(current_section, property_name)
            if _is_missing_config_value(current_value):
                setattr(current_section, property_name, default_value)


def _transform_config(config: Config):
    """Transform certain config fields to another data type and/or value."""
    _fill_missing_config_values(config)

    config.general.log_level = config.general.log_level.upper()

    token_file = _check_config_none(config.entsoe.token_file)
    if _is_missing_config_value(token_file) or token_file is None:
        token_file = defaults.DEFAULT_ENTSOE_TOKEN_FILE
    config.entsoe.token_file = Path(token_file).expanduser()

    log_dir = _check_config_none(config.paths.log_dir)
    if _is_missing_config_value(log_dir) or log_dir is None:
        log_dir = defaults.DEFAULT_LOG_DIR
    config.paths.log_dir = Path(log_dir).expanduser()

    data_dir = _check_config_none(config.paths.data_dir)
    if _is_missing_config_value(data_dir) or data_dir is None:
        data_dir = defaults.DEFAULT_DATA_DIR
    config.paths.data_dir = Path(data_dir).expanduser()
    config.paths.price_data_dir = config.paths.data_dir / defaults.PRICE_DATA_SUBDIR_NAME

    apns_key_file = config.apns.key_file
    if _is_empty_or_missing_config_value(apns_key_file):
        apns_key_file = defaults.DEFAULT_APNS_KEY_FILE
    config.apns.key_file = Path(apns_key_file).expanduser()

    config.cronitor.enabled = _coerce_bool(config.cronitor.enabled)
    config.cronitor.api_key = _check_config_none(config.cronitor.api_key)
    config.cronitor.monitor_key = _check_config_none(config.cronitor.monitor_key)
    config.cronitor.environment = _check_config_none(config.cronitor.environment)

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


def get_config() -> Config:
    """Read and transform config and check some requirements."""
    # First path in list will be used for creation if no config file exists yet.
    read_attempt_paths = [
        Path("~/awattprice/config.ini").expanduser(),
        Path("/etc/awattprice/config.ini"),
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
        config_path = read_attempt_paths[1]
        sys.stdout.write(f"INFO: No config file found. Creating at {config_path}.\n")
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
        diagnose=False,
        rotation="1 week",
    )
