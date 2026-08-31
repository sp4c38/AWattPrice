# Manual Price Import Runbook (Emergency)

Use this when the ENTSO-E Web API is unavailable (outage, rate-limit, credential
issue) close to the time tomorrow's prices are expected, and users would
otherwise get no new prices. The Transparency Platform *website* often still
lets you export a day as XML by hand even while the *API* is down — this
procedure gets that export into production without touching anything else.

This was first done manually on 2026-08-31 for AT and DE-LU while
`web-api.tp.entsoe.eu` was down; [`manual_price_import.py`](../misc/manual_price_import.py)
generalizes that one-off script to any region.

## When to use this

- The ENTSO-E outage page or `/prices/<area>` errors confirm the API itself is
  down, not just one area's data being late.
- The Transparency Platform website (`transparency.entsoe.eu`) can still
  export the affected day for the affected bidding zone(s) as XML.
- It's close enough to the cutover that waiting for the API to recover risks
  shipping the app with no prices for tomorrow.

Don't use this to backfill history or to "help" a refresh that's just running
late — the regular refresher (`awattprice_refresher`) already retries and
prefers its own downloads. This is only for filling a gap the automated path
cannot currently fill itself.

## 1. Export the XML from the Transparency Platform

For each affected bidding zone, use the Transparency Platform's day-ahead
prices report to export tomorrow's day as XML. Save the files locally (their
filenames don't matter — the import script identifies the region from the
EIC domain code inside each file, not the filename).

## 2. Back up the live database first

```bash
ssh aws "sudo cp /etc/awattprice-v3/data/prices.sqlite /etc/awattprice-v3/data/prices.sqlite.backup-before-manual-$(date +%Y%m%d)"
```

This mirrors the backup left from the 2026-08-31 import
(`prices.sqlite.backup-before-manual-20260901` is still on the server as a
reference for what that looks like). If anything goes wrong, restoring is a
straight file copy back over `prices.sqlite` (all three v3 containers must be
stopped and restarted for SQLite/WAL to pick it up cleanly).

## 3. Copy the files onto the server, then into the container

```bash
scp path/to/export1.xml path/to/export2.xml aws:/tmp/awattprice-manual-import/
scp backend/misc/manual_price_import.py aws:/tmp/awattprice-manual-import/

ssh aws "docker cp /tmp/awattprice-manual-import awattprice-data-refresher-v3:/tmp/manual-import"
```

`awattprice-data-refresher-v3` is the container with the venv and the
`awattprice`/`awattprice_refresher` packages installed, and its
`/etc/awattprice/data` is the same bind-mounted SQLite file the API and
notification containers read (mounted from `/etc/awattprice-v3/data` on the
host — see `compose.v3.yaml`). Any of the three v3 containers would work; this
one is picked because it already imports `awattprice_refresher`.

## 4. Run the import inside the container

```bash
ssh aws "docker exec awattprice-data-refresher-v3 python /tmp/manual-import/manual_price_import.py /tmp/manual-import/export1.xml /tmp/manual-import/export2.xml"
```

The script, per file:

1. Detects the market area from the XML's `in_Domain.mRID` EIC code.
2. Parses it with the same `parse_downloaded_data()` the real refresher uses.
3. Refuses to import if the day isn't fully covered, or if the export
   unexpectedly contains fallback-sequence prices instead of the primary
   auction.
4. Merges the new points into whatever is already stored (new points win by
   timestamp; nothing else in the cache is touched).
5. Writes it back to SQLite, updates the refresh timestamp, then reloads from
   SQLite and re-verifies tomorrow is complete before printing success.

A failure on one file is reported and skipped — it does not stop the other
files in the same run. Watch stdout/stderr for `Imported and verified ...`
per region and any `FAILED ...` lines.

## 5. Verify from outside the container

```bash
curl -s https://api.awattprice.com/v3/prices/AT | python3 -m json.tool | head -20
```

Repeat for each imported area. Confirm tomorrow's date is present with
`is_fallback: false` for all points.

## 6. Clean up

```bash
ssh aws "docker exec awattprice-data-refresher-v3 rm -rf /tmp/manual-import; rm -rf /tmp/awattprice-manual-import"
```

Leave the SQLite backup from step 2 in place — it's small relative to the
database and is the fastest rollback path if a problem surfaces later.

## 7. Resume normal operation

Once the ENTSO-E API is back, no further action is needed: the regular
refresher will keep polling and will only overwrite these manually-imported
points with better data (see
[price-data-flow.md](price-data-flow.md#cache-replacement) for the
replacement rules) — it won't discard them for being manually sourced.
