# AWattPrice Backend

The backend serves the AWattPrice iOS app. It fetches current electricity prices from the [ENTSO-E Transparency Platform](https://transparency.entsoe.eu/), caches them locally to avoid unnecessary upstream traffic, stores notification settings, and sends "price below" push notifications.

This is backend-developer documentation, not a public API guide. The backend is meant to be used by the app.

## Structure

```text
src/
├── awattprice/
└── awattprice_notifications/
```

- `awattprice`: main FastAPI application, price handling, config, database access, and shared backend logic.
- `awattprice_notifications`: notification services. `price_below/` contains the current notification workflow.

If code is shared across packages and there is no obvious home for it, prefer `src/awattprice/`.

## Data and Configuration

The backend stores cached price data, notification data, logs, APNs data, and other runtime files on disk. Paths come from `config.ini` and default to `~/awattprice/...`.

Config lookup starts with:

- `/etc/awattprice/config.ini`
- `~/.config/awattprice/config.ini`

## Local Setup

The backend uses `uv`.

- Create or update the local environment: `uv sync`
- Run commands inside that environment: `uv run ...`
- Refresh the lockfile after dependency changes: `uv lock`

## Price Data Flow

The backend caches ENTSO-E prices locally and only refreshes when needed.

1. Read the stored price data and last update time.
2. Refresh only if it is past the configured update hour, prices do not yet reach the next midnight, and the last update time allows another fetch.
3. If no refresh is needed, return cached data.
4. If a refresh is needed, acquire a refresh lock so only one request updates prices at a time.
5. Download the latest data.
6. Store it only if it contains new price points.
7. Return the current data in response format.

If lock acquisition times out, the backend falls back to stored data when possible and otherwise returns an error.

## Notification Configuration Tasks

Requests to `POST /notifications/save_configuration/` must include:

- `token`
- `general.area`
- `general.tax`
- optional `general.base_fee`
- `notifications.price_below.active`
- `notifications.price_below.below_value`

## Price Below Service

The price-below service is a periodic worker. In Docker it runs as its own service and sleeps 10 minutes between runs. Running it more often during the usual ENTSO-E update window around 13:00 to 15:00 makes sense; outside that window it can run less often.

Each run:

1. Collects current prices for all supported market areas.
2. Checks whether the underlying price data changed since the previous run.
3. Loads matching users from the backend database.
4. Filters users whose configured threshold is met.
5. Sends notifications.
6. Stores the identifiers/end times used for that run.

If no area changed, the service exits without sending anything.

## Docker

The Docker setup is intended mainly for production, not debugging.

Files:

- `backend/Dockerfile`: shared image for the API and worker.
- `backend/compose.yaml`: runs the web API and the price-below worker as separate services.
- `backend/uv.lock`: lock the Python dependencies used by `uv`.

1. Pull `leonbecker1/awattprice-backend:latest`.
2. Create `/etc/awattprice/` with `app_data/` and `socket/`.
3. Copy `logs/`, `apns/`, and `data/` into `/etc/awattprice/app_data/`.
4. Put `config.ini` at `/etc/awattprice/config.ini` and make sure its paths match the mounted directories.
5. Start it with `docker compose -f backend/compose.yaml up -d`.

For staging, reuse the same compose file with different environment variables instead of keeping a second compose file:

- `AWATTPRICE_IMAGE=leonbecker1/awattprice-backend:pre_release`
- `AWATTPRICE_HOST_ROOT=/etc/staging_awattprice`

Example:

```sh
AWATTPRICE_IMAGE=leonbecker1/awattprice-backend:pre_release \
AWATTPRICE_HOST_ROOT=/etc/staging_awattprice \
docker compose -f backend/compose.yaml up -d
```

This starts:

- `awattprice`: the FastAPI web service
- `price-below`: the notification worker loop

To build locally from the project root:

```sh
docker build -t leonbecker1/awattprice-backend:latest ./backend
```
