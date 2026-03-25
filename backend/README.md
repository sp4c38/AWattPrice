# AWattPrice Backend

The backend serves the AWattPrice iOS app. It fetches current electricity prices from the public [aWATTar API](https://www.awattar.de/services/api), caches them locally to avoid unnecessary upstream traffic, stores notification settings, and sends "price below" push notifications.

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

## Price Data Flow

The backend caches aWATTar prices locally and only refreshes when needed.

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

- the token,
- the task descriptions.

Rules:

- An "add token" task may appear at most once and must be first.
- A subscribe or unsubscribe task may only target one notification type.
- Only send one update task per subject, such as general settings or the `price_below` configuration.

## Price Below Service

The price-below service is not long-running. It should be started periodically, for example by cron. Running it more often during the usual aWATTar update window around 13:00 to 15:00 makes sense; outside that window it can run less often.

Each run:

1. Collects current prices for all supported regions.
2. Checks whether the underlying price data changed since the previous run.
3. Loads matching users from the current backend database and the legacy database.
4. Filters users whose configured threshold is met.
5. Sends notifications.
6. Stores the identifiers/end times used for that run.

If no region changed, the service exits without sending anything.

## Docker

The Docker setup is intended mainly for production, not debugging.

1. Pull `leonbecker1/awattprice-backend`.
2. Create `/etc/awattprice/` with `app_data/` and `socket/`.
3. Copy `logs/`, `apns/`, and `data/` into `/etc/awattprice/app_data/`.
4. Put `config.ini` at `/etc/awattprice/config.ini` and make sure its paths match the mounted directories.
5. Use `backend/docker/docker-compose/docker-compose.yaml` to start the container with `docker compose up -d`.
