from __future__ import annotations

import argparse
import asyncio
import contextlib
import sys

from dataclasses import dataclass
from datetime import date

import arrow
import httpx

from awattprice import configurator
from awattprice import defaults
from awattprice.market_areas import MarketArea
from awattprice.market_areas import list_price_zone_candidates
from awattprice.market_areas import normalize_market_area_key
from awattprice_refresher.prices import get_entsoe_query_params
from awattprice_refresher.prices import get_history_period
from awattprice_refresher.prices import parse_downloaded_data


@dataclass(frozen=True)
class PriceZoneCheck:
    area: MarketArea
    has_prices: bool
    checked_day: date | None
    point_count: int
    detail: str


def completed_days(area: MarketArea, days: int) -> list[date]:
    today_local = arrow.now(area.timezone).floor("day")
    return [today_local.shift(days=-offset).date() for offset in range(1, days + 1)]


async def download_price_xml(
    client: httpx.AsyncClient,
    config,
    area: MarketArea,
    day: date,
) -> bytes:
    period_start, period_end = get_history_period(area, day)
    params = get_entsoe_query_params(area, period_start, period_end)
    params["securityToken"] = config.entsoe.token_file.read_text().strip()

    response = await client.get(config.entsoe.url, params=params)
    response.raise_for_status()
    return response.content


async def check_area(
    client: httpx.AsyncClient,
    config,
    area: MarketArea,
    days: int,
    semaphore: asyncio.Semaphore,
) -> PriceZoneCheck:
    errors = []
    async with semaphore:
        for day in completed_days(area, days):
            try:
                xml_content = await download_price_xml(client, config, area, day)
                price_data = parse_downloaded_data(area, xml_content)
            except Exception as exc:
                errors.append(f"{day}: {exc}")
                continue

            return PriceZoneCheck(
                area=area,
                has_prices=True,
                checked_day=day,
                point_count=len(price_data.prices),
                detail=f"{len(price_data.prices)} price points",
            )

    return PriceZoneCheck(
        area=area,
        has_prices=False,
        checked_day=None,
        point_count=0,
        detail="; ".join(errors[-3:]) or "no checked days",
    )


def format_supported_keys(results: list[PriceZoneCheck]) -> str:
    keys = [result.area.key for result in results if result.has_prices]
    return ", ".join(f'"{key}"' for key in keys)


async def run_checks(
    days: int,
    concurrency: int,
    timeout: float,
    area_key: str | None,
    supported_only: bool,
) -> list[PriceZoneCheck]:
    config = configurator.get_config()
    if not config.entsoe.token_file.is_file():
        raise FileNotFoundError(f"Missing ENTSO-E token file: {config.entsoe.token_file}")

    semaphore = asyncio.Semaphore(concurrency)
    areas = defaults.list_market_areas() if supported_only else list_price_zone_candidates()
    if area_key is not None:
        normalized_area_key = normalize_market_area_key(area_key)
        areas = [area for area in areas if area.key.upper() == normalized_area_key.upper()]
        if not areas:
            raise ValueError(f"Unknown price zone candidate: {area_key}")

    async with httpx.AsyncClient(timeout=timeout) as client:
        tasks = [check_area(client, config, area, days, semaphore) for area in areas]
        return await asyncio.gather(*tasks)


def print_results(results: list[PriceZoneCheck]):
    supported = [result for result in results if result.has_prices]
    unsupported = [result for result in results if not result.has_prices]

    print(f"Checked {len(results)} configured price zones.")
    print(f"Supported with price data: {len(supported)}")
    print(f"Unsupported/no price data: {len(unsupported)}")
    print()

    print("Supported zones:")
    for result in supported:
        print(f"  OK   {result.area.key:<16} {result.area.display_name:<28} {result.checked_day} {result.detail}")

    print()
    print("No price data:")
    for result in unsupported:
        print(f"  MISS {result.area.key:<16} {result.area.display_name:<28} {result.detail}")

    print()
    print("SUPPORTED_PRICE_ZONE_KEYS = [")
    for result in supported:
        print(f'    "{result.area.key}",')
    print("]")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check which configured ENTSO-E zones expose price data.")
    parser.add_argument(
        "--days",
        type=int,
        default=7,
        help="Number of completed local days to try per zone before marking it unsupported.",
    )
    parser.add_argument("--concurrency", type=int, default=4, help="Maximum concurrent ENTSO-E requests.")
    parser.add_argument("--timeout", type=float, default=30, help="HTTP timeout per ENTSO-E request in seconds.")
    parser.add_argument("--area", help="Only check one price zone, for example IT-Centre-North.")
    parser.add_argument(
        "--supported-only",
        action="store_true",
        help="Only re-check zones currently exposed by the app instead of all known candidates.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        results = asyncio.run(
            run_checks(
                args.days,
                args.concurrency,
                args.timeout,
                args.area,
                args.supported_only,
            )
        )
    except Exception as exc:
        print(f"Price zone check failed: {exc}", file=sys.stderr)
        return 1

    print_results(results)
    return 0


if __name__ == "__main__":
    with contextlib.suppress(KeyboardInterrupt):
        raise SystemExit(main())
    raise SystemExit(130)
