"""Resumable monthly ENTSO-E price-history backfill."""

from __future__ import annotations

import argparse
import asyncio

from typing import Iterable

import arrow

from loguru import logger

from awattprice import configurator
from awattprice import defaults
from awattprice import price_database
from awattprice import prices
from awattprice_refresher import prices as price_refresher


def monthly_periods(start: arrow.Arrow, end: arrow.Arrow) -> Iterable[tuple[arrow.Arrow, arrow.Arrow]]:
    """Yield calendar-month chunks clipped to the requested local range."""
    cursor = start
    while cursor < end:
        next_month = cursor.floor("month").shift(months=+1)
        period_end = min(next_month, end)
        yield cursor, period_end
        cursor = period_end


async def backfill_area(
    area_key: str,
    start: arrow.Arrow,
    end: arrow.Arrow,
    config,
    force: bool,
    prepare_current: bool = True,
) -> int:
    """Backfill one area, refresh its current dataset, and return failures."""
    area = defaults.get_market_area(area_key)
    failures = 0
    for period_start, period_end in monthly_periods(start.to(area.timezone), end.to(area.timezone)):
        start_timestamp = period_start.int_timestamp
        end_timestamp = period_end.int_timestamp
        if not force and await asyncio.to_thread(
            price_database.import_is_complete,
            config,
            area.key,
            start_timestamp,
            end_timestamp,
        ):
            logger.info(f"Skipping completed {area.key} import {period_start.date()}–{period_end.date()}.")
            continue

        await asyncio.to_thread(
            price_database.record_import,
            config,
            area.key,
            start_timestamp,
            end_timestamp,
            "running",
        )
        try:
            xml = await price_refresher.download_data(area, config, period_start, period_end)
            if xml is None:
                raise RuntimeError("ENTSO-E returned no price data.")
            data = price_refresher.parse_downloaded_data(area, xml, now=end)
            if not prices.has_complete_price_points(data, period_start, period_end):
                raise RuntimeError("Downloaded intervals do not continuously cover the requested period.")
            await asyncio.to_thread(
                price_database.store_dataset,
                config,
                area.key,
                f"archive:{start_timestamp}:{end_timestamp}",
                data,
            )
            await asyncio.to_thread(
                price_database.record_import,
                config,
                area.key,
                start_timestamp,
                end_timestamp,
                "complete",
                len(data.prices),
            )
            logger.info(
                f"Imported {len(data.prices)} {area.key} prices for "
                f"{period_start.date()}–{period_end.date()}."
            )
        except Exception as exc:
            failures += 1
            await asyncio.to_thread(
                price_database.record_import,
                config,
                area.key,
                start_timestamp,
                end_timestamp,
                "failed",
                0,
                str(exc),
            )
            logger.error(
                f"Failed {area.key} import {period_start.date()}–{period_end.date()}: {exc}."
            )
        await asyncio.sleep(1)

    if prepare_current:
        try:
            stored_current = await prices.get_stored_data(area.key, config)
            refreshed_current = await price_refresher.refresh_current_prices(
                stored_current,
                area.key,
                config,
            )
            current = refreshed_current or await prices.get_stored_data(area.key, config)
            if current is None or not prices.has_current_price_points(current, area):
                raise RuntimeError("Current prices could not be prepared.")
            logger.info(f"Prepared current SQLite prices for {area.key}.")
        except Exception as exc:
            failures += 1
            logger.error(f"Failed to prepare current prices for {area.key}: {exc}.")
    return failures


async def backfill_areas(
    area_keys: Iterable[str],
    years: int,
    config,
    force: bool = False,
    prepare_current: bool = True,
    concurrency: int = defaults.PRICE_ARCHIVE_CONCURRENCY,
) -> int:
    """Backfill a set of areas and return the combined failure count."""
    now = arrow.now("UTC")
    semaphore = asyncio.Semaphore(concurrency)

    async def backfill_one(raw_area_key: str) -> int:
        area_key = defaults.normalize_market_area_key(raw_area_key)
        area = defaults.get_market_area(area_key)
        end = now.to(area.timezone).floor("day")
        start = end.shift(years=-years)
        async with semaphore:
            return await backfill_area(
                area_key,
                start,
                end,
                config,
                force,
                prepare_current=prepare_current,
            )

    failures = await asyncio.gather(*(backfill_one(area_key) for area_key in area_keys))
    return sum(failures)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Backfill the SQLite ENTSO-E price archive.")
    parser.add_argument(
        "--areas",
        nargs="+",
        default=defaults.supported_market_area_keys,
        help="Market area keys. Defaults to all supported areas.",
    )
    parser.add_argument("--years", type=int, default=2, choices=range(1, 6))
    parser.add_argument("--force", action="store_true", help="Download completed chunks again.")
    return parser.parse_args()


async def async_main() -> int:
    args = parse_args()
    config = configurator.get_config()
    configurator.configure_loguru("awattprice-price-history-backfill", config)
    failures = await backfill_areas(
        args.areas,
        args.years,
        config,
        force=args.force,
    )
    return 1 if failures else 0


def main() -> None:
    raise SystemExit(asyncio.run(async_main()))


if __name__ == "__main__":
    main()
