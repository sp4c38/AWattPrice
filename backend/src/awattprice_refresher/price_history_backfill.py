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
from awattprice import price_statistics
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


def daily_periods(start: arrow.Arrow, end: arrow.Arrow) -> Iterable[tuple[arrow.Arrow, arrow.Arrow]]:
    """Yield local-day chunks clipped to the requested range."""
    cursor = start
    while cursor < end:
        period_end = min(cursor.shift(days=+1), end)
        yield cursor, period_end
        cursor = period_end


async def stored_period_is_complete(
    config,
    area_key: str,
    start: arrow.Arrow,
    end: arrow.Arrow,
) -> bool:
    """Return whether SQLite continuously covers a period."""
    return await asyncio.to_thread(
        price_database.period_is_complete,
        config,
        area_key,
        start.int_timestamp,
        end.int_timestamp,
    )


async def stored_period_coverage(
    config,
    area_key: str,
    start: arrow.Arrow,
    end: arrow.Arrow,
) -> tuple[list[dict], dict]:
    """Load a stored period and evaluate the shared statistics coverage policy."""
    stored_points = await asyncio.to_thread(
        price_database.load_points,
        config,
        area_key,
        start.int_timestamp,
        end.int_timestamp,
    )
    return stored_points, price_statistics.coverage_for_period(stored_points, start, end)


async def store_archive_data(config, area_key: str, start: arrow.Arrow, end: arrow.Arrow, data) -> None:
    """Store downloaded archive data under a period-specific dataset key."""
    await asyncio.to_thread(
        price_database.store_dataset,
        config,
        area_key,
        f"archive:{start.int_timestamp}:{end.int_timestamp}",
        data,
    )


async def fill_missing_days(
    area,
    config,
    start: arrow.Arrow,
    end: arrow.Arrow,
    force: bool = False,
) -> list[str]:
    """Download only local days that are not already complete in SQLite."""
    failed_days = []
    for day_start, day_end in daily_periods(start, end):
        if not force and await stored_period_is_complete(config, area.key, day_start, day_end):
            continue

        try:
            xml = await price_refresher.download_data(area, config, day_start, day_end)
            if xml is None:
                raise RuntimeError("ENTSO-E returned no price data.")
            data = price_refresher.parse_downloaded_data(area, xml, now=end)
            if not prices.has_complete_price_points(data, day_start, day_end):
                raise RuntimeError("Downloaded intervals do not continuously cover the requested day.")
            await store_archive_data(config, area.key, day_start, day_end, data)
        except Exception as exc:
            failed_days.append(f"{day_start.date()} ({exc})")
        await asyncio.sleep(1)

    return failed_days


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
        if not force:
            _, coverage = await stored_period_coverage(
                config,
                area.key,
                period_start,
                period_end,
            )
            if coverage["is_usable"]:
                continue

        try:
            stored_points, _ = await stored_period_coverage(
                config,
                area.key,
                period_start,
                period_end,
            )
            monthly_data_is_complete = False
            if force or not stored_points:
                try:
                    xml = await price_refresher.download_data(area, config, period_start, period_end)
                    if xml is not None:
                        data = price_refresher.parse_downloaded_data(area, xml, now=end)
                        await store_archive_data(config, area.key, period_start, period_end, data)
                        monthly_data_is_complete = prices.has_complete_price_points(
                            data,
                            period_start,
                            period_end,
                        )
                except Exception as exc:
                    logger.debug(
                        f"Monthly {area.key} import {period_start.date()}–{period_end.date()} "
                        f"was unusable; falling back to daily requests: {exc}."
                    )

            failed_days = []
            if not monthly_data_is_complete and not await stored_period_is_complete(
                config,
                area.key,
                period_start,
                period_end,
            ):
                failed_days = await fill_missing_days(
                    area,
                    config,
                    period_start,
                    period_end,
                    force=force,
                )

            stored_points, coverage = await stored_period_coverage(
                config,
                area.key,
                period_start,
                period_end,
            )
            if not coverage["is_usable"]:
                detail = "; ".join(failed_days[:3])
                if len(failed_days) > 3:
                    detail += f"; and {len(failed_days) - 3} more"
                raise RuntimeError(
                    f"Daily fallback left {len(failed_days)} unavailable days"
                    + (f": {detail}" if detail else ".")
                )

            if coverage["is_complete"]:
                logger.info(
                    f"Downloaded and stored {len(stored_points)} {area.key} prices for "
                    f"{period_start.date()}–{period_end.date()}."
                )
            else:
                logger.info(
                    f"Accepted {area.key} archive {period_start.date()}–{period_end.date()} "
                    f"with {coverage['percent']:.1f}% coverage and a maximum gap of "
                    f"{coverage['maximum_gap_seconds'] / 3600:.0f}h."
                )
        except Exception as exc:
            failures += 1
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
    requested_area_keys = tuple(area_keys)

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

    failures = await asyncio.gather(*(backfill_one(area_key) for area_key in requested_area_keys))
    failure_count = sum(failures)
    if failure_count == 0:
        logger.info(
            f"Price archive coverage is complete for all {len(requested_area_keys)} checked areas."
        )
    return failure_count


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
