# Run the AWattPrice backend inside a docker container

The docker container is intended foremost for production environments. For debugging another setup should be used.

1. Run `docker pull leonbecker1/awattprice-backend`.
2. Create the directory `/etc/awattprice`. Inside it create an `app_data` and a `socket` directory.
3. Copy your `logs`, `apns` and `data` directory into the created `app_data` directory. Copy your `config.ini` for AWattPrice into `/etc/awattprice/config.ini`. Make sure the paths inside your config file point to your `logs`, `apns`, ... directories at the paths you just installed them to.
4. Download the docker-compose.yaml file located at `backend/docker/docker-compose.yaml` to whatever place you like.
5. Run `docker compose -f [path to compose file] up -d`. Now the service should be running.

<span style="color:orange;">Note:</span> When shutting down the service (with `docker compose -f [path to compose file] stop`) it may take a few seconds to do so.
