# AWattPrice Backend

FastAPI backend for AWattPrice. It serves ENTSO-E electricity prices, caches them locally, and stores notification settings.

## Local Debug

```sh
./run-local.sh
```

## First Server Setup

NGINX must already proxy `/api/v3/` to `http://127.0.0.1:8003/`.

The v3 deploy uses separate defaults so it does not touch the existing v2 server:

```text
/etc/awattprice-v3
/srv/awattprice-v3/compose.yaml
awattprice-backend-v3
127.0.0.1:8003
```

Create the required server paths:

```sh
sudo mkdir -p /etc/awattprice-v3/app_data/{data,logs,apns}
sudo mkdir -p /srv/awattprice-v3
sudo chown "$USER:$USER" /srv/awattprice-v3
sudo nano /etc/awattprice-v3/config.ini
sudo nano /etc/awattprice-v3/entsoe-token.txt
```

Optional for Price Guard push notifications:

```text
/etc/awattprice-v3/app_data/apns/encryption_key.p8
/etc/awattprice-v3/config.ini with apns.team_id and apns.key_id
```

The deploy script only checks these files. It does not create config on the server.
It stores the Docker Compose file at `/srv/awattprice-v3/compose.yaml`.

## Deploy

Default deploy uploads the backend source and builds the Docker image on the server. This is much faster than uploading the full image each time.

```sh
./deploy.v3.sh user@server
```

If building on Apple Silicon for an x86 server:

```sh
AWATTPRICE_DOCKER_PLATFORM=linux/amd64 ./deploy.v3.sh user@server
```

To also run the Price Guard worker:

```sh
AWATTPRICE_RUN_WORKER=1 ./deploy.v3.sh user@server
```

Fallback to local image build/upload:

```sh
AWATTPRICE_DEPLOY_MODE=image ./deploy.v3.sh user@server
```

The SSH user must be able to run Docker on the server. If you need a custom remote Docker command:

```sh
AWATTPRICE_REMOTE_DOCKER="sudo docker" ./deploy.v3.sh user@server
```

Override defaults if needed:

```sh
AWATTPRICE_HOST_PORT=8013 AWATTPRICE_HOST_ROOT=/etc/my-v3-root ./deploy.v3.sh user@server
```

Manage the container on the server:

```sh
cd /srv/awattprice-v3
docker compose ps
docker compose logs -f
docker compose restart
docker compose down
```

Smoke test:

```sh
curl https://awattprice.space8.me/api/v3/areas/
curl https://awattprice.space8.me/api/v3/prices/DE-LU
```
