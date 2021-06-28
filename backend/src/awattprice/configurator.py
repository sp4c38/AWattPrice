"""Read, store and set configurations.."""
import sys

from pathlib import Path

from liteconfig import Config
from loguru import logger

from awattprice import defaults


def _transform_config(config: Config) -> Config:
    """Transform certain config fields to another data type and/or value.

    Example: Transform path string into a pathlib Path instance.
    """
    config.paths.log_dir = Path(config.paths.log_dir).expanduser()
    config.paths.data_dir = Path(config.paths.data_dir).expanduser()
    config.paths.price_data_dir = config.paths.data_dir / defaults.PRICE_DATA_SUBDIR_NAME

    return config


def _ensure_dir(path: Path):
    """Ensure that the dir at the parsed path is a directory and exists.

    If the directory doesn't exist create it.

    :raises NotADirectoryError: if the parsed path is anything but a directory.
    :returns: If this returns the path is a directory and it exists.
    """
    if not path.exists():
        logger.info(f"Creating missing directory referred to in the config: {path}.")
        path.mkdir(parents=True)

    if not path.is_dir():
        logger.critical(f"Directory referred to in the config is no directory: {path}.")
        raise NotADirectoryError


def _ensure_config_dirs(config: Config):
    """Ensure certain directories referred to in the config exist."""
    _ensure_dir(config.paths.log_dir)
    _ensure_dir(config.paths.data_dir)
    _ensure_dir(config.paths.price_data_dir)


def get_config():
    """Read the config and setup localconfig's global config variable.

    To use the config import the global config variable from localconfig.
    """
    # First path in list will be used for creation if no config file exists yet.
    read_attempt_paths = [
        Path("~/.config/awattprice/config.ini").expanduser(),
        Path("/etc/awattprice/config.ini"),
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
            config_file.write(defaults.DEFAULT_CONFIG)
        config = Config(defaults.DEFAULT_CONFIG)

    config = _transform_config(config)
    _ensure_config_dirs(config)

    return config


def configure_loguru(service_name: str, config: Config):
    """Configure loguru's logger.

    :param service_name: Name of the service for which logging should be registered.
    """
    log_dir_path = config.paths.log_dir
    if log_dir_path.exists():
        if not log_dir_path.is_dir():
            sys.stderr.write(f"Directory used to store logs {log_dir_path.as_posix()} is not a directory.\n")
            sys.exit(1)
    else:
        sys.stdout.write(f"Log directory missing. Creating at {log_dir_path}.\n")
        log_dir_path.mkdir(parents=True, exist_ok=True)

    log_name = service_name + ".log"
    log_path = log_dir_path / (service_name + ".log")
    logger.add(
        log_path,
        enqueue=True,  # This makes log calls non-blocking.
        colorize=None,
        backtrace=True,
        diagnose=config.general.debug,
        rotation="1 week",
    )
