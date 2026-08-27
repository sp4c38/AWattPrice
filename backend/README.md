# AWattPrice Backend

FastAPI backend for AWattPrice. It serves ENTSO-E electricity prices, caches them locally, and stores notification settings.

## Local Debug

Place the ENTSO-E token at `~/awattprice-v3-local/entsoe-token.txt`, then start the backend:

```sh
./run-local.sh
```

This creates the isolated local configuration and SQLite database under
`~/awattprice-v3-local`, starts the API, and runs the regular production data-refresher for
every supported area. Current/tomorrow prices, retained daily history, generation mix, and
the two-year price archive populate automatically. No preparation command is required.

The local launcher does not start notifications. Cronitor telemetry is skipped because the
isolated configuration uses the `local` environment and has no monitoring credentials.

The iOS Debug configuration can use it by setting `AWATTPRICE_API_BASE_URL` to `http://127.0.0.1:8000/` in the scheme environment.

## Price Selection

Prices are imported from the ENTSO-E Transparency Platform by the refresher and then served from the local cache by the API.

For ENTSO-E day-ahead price documents with sequence data, AWattPrice treats Sequence 1 as authoritative. For DE-LU this is the SDAC day-ahead price series. ENTSO-E `A03` step curves may omit repeated prices; the refresher expands those intervals by carrying the previous price forward before it looks at fallback sequences.

If individual intervals are still missing after Sequence 1 step-curve expansion, the refresher fills only those missing intervals from later available sequences, usually Sequence 2. Sequence 1 prices always win when present or carried forward. Sequence fallback points are marked with `is_fallback = true`; carried-forward step-curve points are marked with `is_carried_forward = true`.

The refresher keeps treating incomplete or fallback data as replaceable. If ENTSO-E later publishes the missing Sequence 1 price, that real price replaces the fallback point in the cache.

Current prices and the long-term archive are stored in `/etc/awattprice/data/prices.sqlite`. Existing price pickle files are neither read nor written. Notification profiles and notification progress files remain unchanged.

## Automatic Price History Archive

The regular data-refresher automatically populates the two-year SQLite archive for every
supported area after its first normal refresh cycle. Monthly imports are skipped only when
the stored price intervals continuously cover the requested period. Missing intervals are
downloaded automatically, including when an older completion marker exists, and already
complete data is reused even when no matching marker exists. Several regions are populated
in parallel with a bounded request count, so one slow region cannot block all remaining
regions. Already-complete monthly chunks are silent; a single summary is logged after all
configured regions have been checked.

No deployment or local setup command is required. The importer remains available only for
manual maintenance or troubleshooting:

```sh
docker compose -f /srv/awattprice-v3/compose.v3.yaml exec api \
  python -m awattprice_refresher.price_history_backfill --years 2
```

To run it for one area only, add `--areas DE-LU`. The importer does not start the
notifications service and does not modify any notification-owned file.

The app requests adjusted statistics through `POST /prices/{area}/statistics`. The request contains the selected range and the user's ordered price adjustments, so the backend reproduces the displayed ct/kWh value for every interval before calculating duration-weighted statistics.

Statistics are calculated on demand and are not stored. The existing refresher cleanup also
prunes SQLite price points, dataset metadata, and import records older than two years plus a
one-month safety margin.

Generation mix endpoint compatibility is documented in [docs/generation-mix-data-flow.md](docs/generation-mix-data-flow.md).

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

Required Cronitor job monitoring for the notifications worker and data refresher:

```ini
[cronitor]
api_key = <cronitor api key>
monitor_key = <notifications worker job key>
refresher_monitor_key = <data refresher job key>
environment = production
```

Configure both Cronitor monitors as Jobs. The notifications monitor should use a schedule slightly longer than the worker loop, for example 15 minutes for the 10 minute scheduler interval. The refresher monitor should use a schedule slightly longer than its 60 second scheduler heartbeat. Each worker cycle sends `run`, then `complete` for normal outcomes or `fail` for unhandled errors. The workers exit if their Cronitor credentials are missing.

## Deploy

Use `deploy-blue-green.v3.sh` for deployment. The script backs up
`notification-profiles.json` to `backups/notification-profiles/` before it
builds or changes anything on the server.

Smoke test after deploy:

```sh
curl https://api.awattprice.com/v3/areas/
curl https://api.awattprice.com/v3/prices/DE-LU
curl -X POST https://api.awattprice.com/v3/prices/DE-LU/statistics \
  -H 'Content-Type: application/json' \
  -d '{"range":"1mo","add_ons":[]}'
```
