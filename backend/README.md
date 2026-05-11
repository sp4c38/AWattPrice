# AWattPrice Backend

FastAPI backend for AWattPrice. It serves ENTSO-E electricity prices, caches them locally, and stores notification settings.

## Local Debug

```sh
./run-local.sh
```

## First Server Setup

NGINX must already proxy `/v3/` on `api.awattprice.com` to `http://127.0.0.1:8003/`.

The v3 deploy uses separate defaults so it does not touch the existing v2 server. Required runtime files live directly under `/etc/awattprice-v3`, and the deployed Compose file is stored under `/srv/awattprice-v3`.

Inside the container, configure paths as `/etc/awattprice/data`, `/etc/awattprice/logs`, and `apns.key_file=/etc/awattprice/encryption_key.p8`. Docker Compose maps those to `/etc/awattprice-v3/data`, `/etc/awattprice-v3/logs`, and `/etc/awattprice-v3/encryption_key.p8` on the host.

Optional for push notifications:

```text
/etc/awattprice-v3/encryption_key.p8
/etc/awattprice-v3/config.ini with apns.team_id, apns.key_id, and apns.key_file
```

## Deploy

Use `deploy.v3.sh` for deployment. Smoke test after deploy:

```sh
curl https://api.awattprice.com/v3/areas/
curl https://api.awattprice.com/v3/prices/DE-LU
```
