# AWattPrice Backend

FastAPI backend for AWattPrice. It serves ENTSO-E electricity prices, caches them locally, and stores notification settings.

## Local Debug

```sh
./run-local.sh
```

## First Server Setup

NGINX must already proxy `/v3/` on `api.awattprice.com` to `http://127.0.0.1:8003/`.

The v3 deploy uses separate defaults so it does not touch the existing v2 server. Required runtime files live directly under `/etc/awattprice-v3`, and the deployed Compose file is stored under `/srv/awattprice-v3`.

Docker Compose is the only place that maps host paths to container paths. For normal Docker deployment, `config.ini` should not set file or directory paths. The backend defaults to these container paths:

```text
/etc/awattprice/entsoe-token.txt
/etc/awattprice/encryption_key.p8
/etc/awattprice/data
/etc/awattprice/logs
```

Optional for push notifications:

```text
/etc/awattprice-v3/encryption_key.p8
/etc/awattprice-v3/config.ini with apns.team_id and apns.key_id
```

## Deploy

Use `deploy.v3.sh` for deployment. Smoke test after deploy:

```sh
curl https://api.awattprice.com/v3/areas/
curl https://api.awattprice.com/v3/prices/DE-LU
```
