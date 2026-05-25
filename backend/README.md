# AWattPrice Backend

FastAPI backend for AWattPrice. It serves ENTSO-E electricity prices, caches them locally, and stores notification settings.

## Local Debug

```sh
./run-local.sh
```

## Maintenance Checks

Check which configured ENTSO-E price zones currently expose price data:

```sh
PYTHONPATH=src .venv/bin/python misc/check_price_zones.py --days 7 --concurrency 4 --timeout 30
```

Run this from the backend directory. The script uses the configured ENTSO-E token and checks all known price-zone candidates, including zones the app does not currently expose. It prints the supported zones that should remain in `SUPPORTED_PRICE_ZONE_KEYS` in `src/awattprice/market_areas.py`.

To verify one zone:

```sh
PYTHONPATH=src .venv/bin/python misc/check_price_zones.py --area IT-Centre-North --days 7 --concurrency 1 --timeout 30
```

## First Server Setup

NGINX must already proxy `/v3/` on `api.awattprice.com` to `http://127.0.0.1:8003/`.

The v3 deploy uses separate defaults so it does not touch the existing v2 server. Required runtime files live directly under `/etc/awattprice-v3`, and the deployed Compose file is stored under `/srv/awattprice-v3`.

Docker Compose is the only place that maps host paths to container paths. The backend defaults to these container paths:

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

Required Cronitor job monitoring for the notifications worker:

```ini
[cronitor]
api_key = <cronitor api key>
monitor_key = <cronitor job key>
environment = production
```

Configure the Cronitor monitor as a Job with a schedule slightly longer than the worker loop, for example 15 minutes for the 10 minute Docker loop. Each worker cycle sends `run`, then `complete` for normal outcomes or `fail` for unhandled errors. The notifications worker exits if Cronitor credentials are missing.

## Deploy

Use `deploy.v3.sh` for deployment. Smoke test after deploy:

```sh
curl https://api.awattprice.com/v3/areas/
curl https://api.awattprice.com/v3/prices/DE-LU
```
