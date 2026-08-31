"""Manually import ENTSO-E day-ahead prices from Transparency Platform XML exports.

Emergency use only: for when the ENTSO-E Web API is down (or rate-limiting) but
the Transparency Platform website still lets you export a day's prices as XML
by hand. Run this inside the awattprice-data-refresher-v3 container against
one or more exported files; it merges each into the existing SQLite cache
without touching anything else. See
backend/docs/manual-price-import-runbook.md for the full step-by-step
procedure, including how to get the files onto the server and back up the
database first.

Usage (inside the container):
    python /tmp/manual_price_import.py [--day YYYY-MM-DD] export1.xml export2.xml ...

The market area for each file is auto-detected from the EIC domain code
inside the XML (the `in_Domain.mRID` element), so files can be passed in any
order and don't need to be renamed. `--day` defaults to tomorrow (UTC) since
that's the case this script exists for; pass it explicitly when backfilling a
different day.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import xml.etree.ElementTree as ET

from datetime import date
from pathlib import Path

import arrow

from box import BoxList

from awattprice import defaults
from awattprice import prices
from awattprice.configurator import get_config
from awattprice.market_areas import list_price_zone_candidates
from awattprice_refresher.prices import parse_downloaded_data
from awattprice_refresher.prices import update_last_update_time


def detect_area_key(xml_bytes: bytes) -> str:
    """Identify the market area from the EIC domain code inside the export."""
    root = ET.fromstring(xml_bytes)
    domain = root.findtext(".//{*}in_Domain.mRID")
    if domain is None:
        raise ValueError("Could not find in_Domain.mRID in the export.")

    matching_areas = [area for area in list_price_zone_candidates() if area.entsoe_domain == domain]
    if not matching_areas:
        raise ValueError(f"No known market area for EIC domain {domain}.")

    supported_areas = [area for area in matching_areas if area.key in defaults.supported_market_area_keys]
    return (supported_areas or matching_areas)[0].key


async def import_one(config, xml_path: Path, import_day: date) -> None:
    """Import, merge, store, and verify a single exported day for one area."""
    xml_bytes = xml_path.read_bytes()
    area_key = detect_area_key(xml_bytes)
    area = defaults.get_market_area(area_key)

    imported = parse_downloaded_data(area, xml_bytes)
    if not prices.has_complete_local_day(imported, area, import_day):
        raise RuntimeError(f"{xml_path.name}: export does not contain a complete {import_day} local day")
    if prices.fallback_price_count(imported) != 0:
        raise RuntimeError(f"{xml_path.name}: export unexpectedly contains fallback prices")

    stored = await prices.get_stored_data(area_key, config)
    if stored is None:
        merged = imported
    else:
        points_by_start = {point.start_timestamp.int_timestamp: point for point in stored.prices}
        points_by_start.update({point.start_timestamp.int_timestamp: point for point in imported.prices})
        stored.prices = BoxList(sorted(points_by_start.values(), key=lambda point: point.start_timestamp))
        merged = stored

    await prices.store_data(merged, area_key, config)
    await update_last_update_time(area_key, config)

    reloaded = await prices.get_stored_data(area_key, config)
    verification_time = arrow.now(area.timezone).floor("day").shift(hours=18)
    if not prices.complete_tomorrow_prices(reloaded, area, now=verification_time):
        raise RuntimeError(f"{area_key}: stored data failed tomorrow-price verification after import")

    imported_count = sum(
        1 for point in reloaded.prices if point.start_timestamp.to(area.timezone).date() == import_day
    )
    print(f"Imported and verified {imported_count} {area_key} intervals for {import_day} ({xml_path.name}).")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("xml_files", nargs="+", type=Path, help="Exported Transparency Platform XML files.")
    parser.add_argument(
        "--day",
        type=date.fromisoformat,
        default=None,
        help="Local day the exports cover (YYYY-MM-DD). Defaults to tomorrow (UTC).",
    )
    return parser.parse_args()


async def async_main() -> int:
    args = parse_args()
    import_day = args.day or arrow.utcnow().shift(days=+1).date()
    config = get_config()

    failures = 0
    for xml_path in args.xml_files:
        try:
            await import_one(config, xml_path, import_day)
        except Exception as exc:
            failures += 1
            print(f"FAILED {xml_path.name}: {exc}", file=sys.stderr)

    return 1 if failures else 0


def main() -> None:
    raise SystemExit(asyncio.run(async_main()))


if __name__ == "__main__":
    main()
