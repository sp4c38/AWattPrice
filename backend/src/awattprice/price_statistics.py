"""Calculate long-term price statistics from the SQLite price archive."""

from __future__ import annotations

import asyncio

from collections import defaultdict
from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

import arrow

from liteconfig import Config
from pydantic import BaseModel, Field, model_validator

from awattprice import price_database
from awattprice import utils
from awattprice.market_areas import MarketArea


MINIMUM_COVERAGE_PERCENT = 95
MAXIMUM_CONTINUOUS_GAP_SECONDS = 24 * 60 * 60
RANGE_KEYS = ("1mo", "3mo", "1yr", "2yr")


class PriceAddOnRequest(BaseModel):
    """One app price adjustment in the exact order selected by the user."""

    kind: Literal["tax", "fixed", "percentage", "monthly"]
    value: Decimal = Decimal("0")


class PriceStatisticsRequest(BaseModel):
    """Configuration used to reproduce the price displayed by the app."""

    add_ons: list[PriceAddOnRequest] = Field(default_factory=list)
    cheap_below: Decimal = Decimal("20")
    expensive_above: Decimal = Decimal("35")

    @model_validator(mode="after")
    def validate_request(self):
        kinds = [add_on.kind for add_on in self.add_ons]
        if len(kinds) != len(set(kinds)):
            raise ValueError("Each price add-on may appear only once.")
        if self.cheap_below >= self.expensive_above:
            raise ValueError("cheap_below must be lower than expensive_above.")
        return self


def range_start(period_end: arrow.Arrow, range_key: str) -> arrow.Arrow:
    """Return the local calendar boundary for a supported statistics range."""
    shifts = {
        "1mo": {"months": -1},
        "3mo": {"months": -3},
        "1yr": {"years": -1},
        "2yr": {"years": -2},
    }
    return period_end.shift(**shifts[range_key])


def adjusted_price(raw_price: str, area: MarketArea, add_ons: list[PriceAddOnRequest]) -> Decimal:
    """Apply app pricing settings to one raw EUR/MWh price interval."""
    value = utils.unitmwh_to_subunitkwh(Decimal(raw_price), area.subunits_per_currency_unit)
    for add_on in add_ons:
        if add_on.kind == "tax":
            if value > 0 and area.tax_multiplier is not None:
                value *= area.tax_multiplier
        elif add_on.kind in ("fixed", "monthly"):
            value += add_on.value
        elif add_on.kind == "percentage":
            value *= Decimal("1") + add_on.value / Decimal("100")
    return value


def weighted_average(values: list[tuple[Decimal, int]]) -> Optional[Decimal]:
    """Calculate an interval-duration-weighted average."""
    duration = sum(item_duration for _, item_duration in values)
    if duration <= 0:
        return None
    return sum(value * item_duration for value, item_duration in values) / Decimal(duration)


def coverage_for_period(
    rows: list[dict],
    period_start: arrow.Arrow,
    period_end: arrow.Arrow,
) -> dict:
    """Measure unique interval coverage and the largest continuous gap."""
    period_start_timestamp = period_start.int_timestamp
    period_end_timestamp = period_end.int_timestamp
    expected_seconds = period_end_timestamp - period_start_timestamp
    available_seconds = 0
    maximum_gap_seconds = 0
    cursor = period_start_timestamp
    for row in rows:
        start_timestamp = max(row["start_timestamp"], period_start_timestamp)
        end_timestamp = min(row["end_timestamp"], period_end_timestamp)
        if end_timestamp <= start_timestamp or end_timestamp <= cursor:
            continue
        if start_timestamp > cursor:
            maximum_gap_seconds = max(maximum_gap_seconds, start_timestamp - cursor)
        covered_start = max(start_timestamp, cursor)
        available_seconds += end_timestamp - covered_start
        cursor = end_timestamp

    if cursor < period_end_timestamp:
        maximum_gap_seconds = max(maximum_gap_seconds, period_end_timestamp - cursor)

    percent = available_seconds / expected_seconds * 100 if expected_seconds > 0 else 0
    is_complete = available_seconds == expected_seconds and maximum_gap_seconds == 0
    return {
        "available_seconds": available_seconds,
        "expected_seconds": expected_seconds,
        "percent": percent,
        "maximum_gap_seconds": maximum_gap_seconds,
        "is_complete": is_complete,
        "is_usable": (
            percent >= MINIMUM_COVERAGE_PERCENT
            and maximum_gap_seconds <= MAXIMUM_CONTINUOUS_GAP_SECONDS
        ),
    }


def _eligible_calendar_months(
    adjusted_rows: list[tuple[dict, Decimal, int, datetime]],
    period_start: arrow.Arrow,
    period_end: arrow.Arrow,
) -> set[tuple[int, int]]:
    """Return complete-range calendar months with enough usable source data."""
    rows_by_month = defaultdict(list)
    for row, _, _, local_start in adjusted_rows:
        rows_by_month[(local_start.year, local_start.month)].append(row)

    eligible = set()
    month_start = period_start.floor("month")
    if month_start < period_start:
        month_start = month_start.shift(months=+1)
    while month_start < period_end:
        month_end = month_start.shift(months=+1)
        if month_end > period_end:
            break
        month_rows = rows_by_month[(month_start.year, month_start.month)]
        if coverage_for_period(month_rows, month_start, month_end)["is_usable"]:
            eligible.add((month_start.year, month_start.month))
        month_start = month_end
    return eligible


def _day_timestamp(local: datetime) -> int:
    return int(local.replace(hour=0, minute=0, second=0, microsecond=0).timestamp())


def _trend_bucket_start(
    local: datetime,
    period_start: arrow.Arrow,
    range_key: str,
    weekly_buckets: dict[int, int],
) -> int:
    if range_key == "1mo":
        return _day_timestamp(local)
    if range_key == "3mo":
        elapsed_days = (local.date() - period_start.date()).days
        week = elapsed_days // 7
        if week not in weekly_buckets:
            weekly_buckets[week] = period_start.shift(days=week * 7).int_timestamp
        return weekly_buckets[week]
    return int(local.replace(day=1, hour=0, minute=0, second=0, microsecond=0).timestamp())


def _highlight_key(local: datetime, range_key: str):
    if range_key == "1mo":
        return _day_timestamp(local)
    if range_key == "3mo":
        return local.isoweekday()
    return local.month


def _build_period_statistics(
    adjusted: list[tuple[dict, Decimal, int, datetime]],
    request: PriceStatisticsRequest,
    range_key: str,
    period_start: arrow.Arrow,
    period_end: arrow.Arrow,
    include_details: bool,
) -> dict:
    rows = [row for row, _, _, _ in adjusted]
    average = weighted_average([(value, duration) for _, value, duration, _ in adjusted])
    coverage = coverage_for_period(rows, period_start, period_end)
    available_seconds = coverage["available_seconds"]
    result = {
        "average_price": float(average) if average is not None else None,
        "coverage": coverage,
    }
    if not include_details or not adjusted or average is None:
        return result

    lowest = min(adjusted, key=lambda item: item[1])
    highest = max(adjusted, key=lambda item: item[1])
    negative_seconds = sum(duration for _, value, duration, _ in adjusted if value < 0)
    below_average_seconds = sum(duration for _, value, duration, _ in adjusted if value < average)

    cheap_seconds = sum(duration for _, value, duration, _ in adjusted if value < request.cheap_below)
    expensive_seconds = sum(duration for _, value, duration, _ in adjusted if value > request.expensive_above)
    typical_seconds = available_seconds - cheap_seconds - expensive_seconds

    trend_values = defaultdict(list)
    highlight_values = defaultdict(list)
    weekly_buckets = {}
    eligible_months = (
        _eligible_calendar_months(adjusted, period_start, period_end)
        if range_key in ("1yr", "2yr")
        else None
    )
    for row, value, duration, local in adjusted:
        trend_values[
            _trend_bucket_start(local, period_start, range_key, weekly_buckets)
        ].append((value, duration))
        if eligible_months is None or (local.year, local.month) in eligible_months:
            highlight_values[_highlight_key(local, range_key)].append((value, duration))

    trend = [
        {"start_timestamp": timestamp, "average_price": float(weighted_average(values))}
        for timestamp, values in sorted(trend_values.items())
    ]
    result.update(
        {
            "lowest": {"price": float(lowest[1]), "timestamp": lowest[0]["start_timestamp"]},
            "highest": {"price": float(highest[1]), "timestamp": highest[0]["start_timestamp"]},
            "negative_hours": negative_seconds / 3600,
            "below_average_percent": below_average_seconds / available_seconds * 100,
            "distribution": {
                "cheap_percent": cheap_seconds / available_seconds * 100,
                "typical_percent": typical_seconds / available_seconds * 100,
                "expensive_percent": expensive_seconds / available_seconds * 100,
                "cheap_below": float(request.cheap_below),
                "expensive_above": float(request.expensive_above),
            },
            "trend": trend,
        }
    )
    if highlight_values:
        highlight_key, highlight_average = min(
            ((key, weighted_average(values)) for key, values in highlight_values.items()),
            key=lambda item: item[1],
        )
        if range_key == "1mo":
            highlight = {"kind": "day", "timestamp": highlight_key}
        elif range_key == "3mo":
            highlight = {"kind": "weekday", "value": highlight_key}
        else:
            highlight = {"kind": "month", "value": highlight_key}
        highlight["average_price"] = float(highlight_average)
        result["highlight"] = highlight
    return result


def _comparison_periods(
    period_start: arrow.Arrow,
    period_end: arrow.Arrow,
    range_key: str,
) -> Optional[tuple[arrow.Arrow, arrow.Arrow, arrow.Arrow, arrow.Arrow]]:
    if range_key == "2yr":
        return None
    previous_start = range_start(period_start, range_key)
    return period_start, period_end, previous_start, period_start


def _rows_in_period(
    adjusted_rows: list[tuple[dict, Decimal, int, datetime]],
    period_start: arrow.Arrow,
    period_end: arrow.Arrow,
) -> list[tuple[dict, Decimal, int, datetime]]:
    """Select a chronological sub-range from the shared adjusted rows."""
    period_start_timestamp = period_start.int_timestamp
    period_end_timestamp = period_end.int_timestamp
    return [
        item
        for item in adjusted_rows
        if item[0]["start_timestamp"] >= period_start_timestamp
        and item[0]["end_timestamp"] <= period_end_timestamp
    ]


def _statistics_for_range(
    adjusted_rows: list[tuple[dict, Decimal, int, datetime]],
    area: MarketArea,
    request: PriceStatisticsRequest,
    range_key: str,
    period_end: arrow.Arrow,
) -> Optional[dict]:
    """Derive one range from the shared, adjusted two-year dataset."""
    period_start = range_start(period_end, range_key)
    comparison_periods = _comparison_periods(
        period_start,
        period_end,
        range_key,
    )
    selected_rows = _rows_in_period(adjusted_rows, period_start, period_end)
    selected = _build_period_statistics(
        selected_rows, request, range_key, period_start, period_end, include_details=True
    )
    if (
        selected["average_price"] is None
        or not selected["coverage"]["is_usable"]
        or "highlight" not in selected
    ):
        return None

    change_percent = None
    if comparison_periods is not None:
        _, _, previous_start, previous_end = comparison_periods
        previous_rows = _rows_in_period(adjusted_rows, previous_start, previous_end)
        previous = _build_period_statistics(
            previous_rows, request, range_key, previous_start, previous_end, include_details=False
        )
        if (
            selected["coverage"]["is_usable"]
            and previous["coverage"]["is_usable"]
            and selected["average_price"] is not None
            and previous["average_price"] not in (None, 0)
        ):
            change_percent = (
                (selected["average_price"] - previous["average_price"])
                / abs(previous["average_price"])
                * 100
            )

    response = {
        "area": area.key,
        "range": range_key,
        "start_timestamp": period_start.int_timestamp,
        "end_timestamp": period_end.int_timestamp,
        "comparison_change_percent": change_percent,
        **selected,
    }
    return response


def calculate_statistics(
    config: Config,
    area: MarketArea,
    request: PriceStatisticsRequest,
    now: Optional[arrow.Arrow] = None,
) -> Optional[dict[str, dict]]:
    """Calculate all long-term ranges from one database read and adjustment pass."""
    period_end = (now or arrow.now(area.timezone)).to(area.timezone).floor("day")
    archive_start = range_start(period_end, "2yr")
    rows = price_database.load_statistic_points(
        config,
        area.key,
        archive_start.int_timestamp,
        period_end.int_timestamp,
    )
    if not rows:
        return None

    adjusted_rows = []
    for row in rows:
        duration = row["end_timestamp"] - row["start_timestamp"]
        if duration <= 0:
            continue
        adjusted_rows.append(
            (
                row,
                adjusted_price(row["marketprice"], area, request.add_ons),
                duration,
                arrow.get(row["start_timestamp"]).to(area.timezone).datetime,
            )
        )

    statistics = {}
    for range_key in RANGE_KEYS:
        result = _statistics_for_range(adjusted_rows, area, request, range_key, period_end)
        if result is not None:
            statistics[range_key] = result
    return statistics or None


async def get_statistics(
    config: Config,
    area: MarketArea,
    request: PriceStatisticsRequest,
) -> Optional[dict]:
    """Calculate all statistics ranges without blocking the API event loop."""
    return await asyncio.to_thread(calculate_statistics, config, area, request)
