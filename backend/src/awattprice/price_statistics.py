"""Calculate long-term price statistics from the SQLite price archive."""

from __future__ import annotations

import asyncio

from collections import defaultdict
from decimal import Decimal
from typing import Literal, Optional

import arrow

from liteconfig import Config
from pydantic import BaseModel, Field, model_validator

from awattprice import price_database
from awattprice import utils
from awattprice.market_areas import MarketArea


class PriceAddOnRequest(BaseModel):
    """One app price adjustment in the exact order selected by the user."""

    kind: Literal["tax", "fixed", "percentage", "monthly"]
    value: Decimal = Decimal("0")


class PriceStatisticsRequest(BaseModel):
    """Configuration used to reproduce the price displayed by the app."""

    range: Literal["1mo", "3mo", "1yr", "2yr"]
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


def _has_complete_coverage(
    rows: list[dict],
    period_start: arrow.Arrow,
    period_end: arrow.Arrow,
) -> bool:
    """Return whether stored intervals continuously cover the requested period."""
    cursor = period_start.int_timestamp
    for row in sorted(rows, key=lambda item: item["start_timestamp"]):
        start_timestamp = row["start_timestamp"]
        end_timestamp = row["end_timestamp"]
        if start_timestamp != cursor or end_timestamp <= start_timestamp:
            return False
        cursor = end_timestamp
    return cursor == period_end.int_timestamp


def _trend_bucket_start(timestamp: int, period_start: arrow.Arrow, range_key: str, timezone: str) -> int:
    local = arrow.get(timestamp).to(timezone)
    if range_key == "1mo":
        return local.floor("day").int_timestamp
    if range_key == "3mo":
        elapsed_days = (local.date() - period_start.date()).days
        return period_start.shift(days=(elapsed_days // 7) * 7).int_timestamp
    return local.floor("month").int_timestamp


def _highlight_key(timestamp: int, range_key: str, timezone: str):
    local = arrow.get(timestamp).to(timezone)
    if range_key == "1mo":
        return local.floor("day").int_timestamp
    if range_key == "3mo":
        return local.isoweekday()
    return local.month


def _build_period_statistics(
    rows: list[dict],
    area: MarketArea,
    request: PriceStatisticsRequest,
    period_start: arrow.Arrow,
    period_end: arrow.Arrow,
    include_details: bool,
) -> dict:
    adjusted = []
    for row in rows:
        duration = row["end_timestamp"] - row["start_timestamp"]
        if duration <= 0:
            continue
        adjusted.append((row, adjusted_price(row["marketprice"], area, request.add_ons), duration))

    average = weighted_average([(value, duration) for _, value, duration in adjusted])
    available_seconds = sum(duration for _, _, duration in adjusted)
    expected_seconds = period_end.int_timestamp - period_start.int_timestamp
    is_complete = _has_complete_coverage(rows, period_start, period_end)
    result = {
        "average_price": float(average) if average is not None else None,
        "coverage": {
            "available_seconds": available_seconds,
            "expected_seconds": expected_seconds,
            "percent": (available_seconds / expected_seconds * 100) if expected_seconds else 0,
            "is_complete": is_complete,
        },
    }
    if not include_details or not adjusted or average is None:
        return result

    lowest = min(adjusted, key=lambda item: item[1])
    highest = max(adjusted, key=lambda item: item[1])
    negative_seconds = sum(duration for _, value, duration in adjusted if value < 0)
    below_average_seconds = sum(duration for _, value, duration in adjusted if value < average)

    cheap_seconds = sum(duration for _, value, duration in adjusted if value < request.cheap_below)
    expensive_seconds = sum(duration for _, value, duration in adjusted if value > request.expensive_above)
    typical_seconds = available_seconds - cheap_seconds - expensive_seconds

    trend_values = defaultdict(list)
    highlight_values = defaultdict(list)
    for row, value, duration in adjusted:
        trend_values[
            _trend_bucket_start(row["start_timestamp"], period_start, request.range, area.timezone)
        ].append((value, duration))
        highlight_values[_highlight_key(row["start_timestamp"], request.range, area.timezone)].append(
            (value, duration)
        )

    trend = [
        {"start_timestamp": timestamp, "average_price": float(weighted_average(values))}
        for timestamp, values in sorted(trend_values.items())
    ]
    highlight_key, highlight_average = min(
        ((key, weighted_average(values)) for key, values in highlight_values.items()),
        key=lambda item: item[1],
    )
    if request.range == "1mo":
        highlight = {"kind": "day", "timestamp": highlight_key}
    elif request.range == "3mo":
        highlight = {"kind": "weekday", "value": highlight_key}
    else:
        highlight = {"kind": "month", "value": highlight_key}
    highlight["average_price"] = float(highlight_average)

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
            "highlight": highlight,
        }
    )
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


def calculate_statistics(
    config: Config,
    area: MarketArea,
    request: PriceStatisticsRequest,
    now: Optional[arrow.Arrow] = None,
) -> Optional[dict]:
    """Calculate and cache one long-term statistics response."""
    period_end = (now or arrow.now(area.timezone)).to(area.timezone).floor("day")
    period_start = range_start(period_end, request.range)
    comparison_periods = _comparison_periods(
        period_start,
        period_end,
        request.range,
    )
    history_start = comparison_periods[2] if comparison_periods is not None else period_start
    all_rows = price_database.load_points(
        config,
        area.key,
        history_start.int_timestamp,
        period_end.int_timestamp,
    )
    if not all_rows:
        return None

    selected_rows = [
        row
        for row in all_rows
        if row["start_timestamp"] >= period_start.int_timestamp
        and row["end_timestamp"] <= period_end.int_timestamp
    ]
    selected = _build_period_statistics(
        selected_rows, area, request, period_start, period_end, include_details=True
    )
    if selected["average_price"] is None or not selected["coverage"]["is_complete"]:
        return None

    change_percent = None
    if comparison_periods is not None:
        comparison_start, comparison_end, previous_start, previous_end = comparison_periods
        comparison_rows = [
            row
            for row in all_rows
            if row["start_timestamp"] >= comparison_start.int_timestamp
            and row["end_timestamp"] <= comparison_end.int_timestamp
        ]
        previous_rows = [
            row
            for row in all_rows
            if row["start_timestamp"] >= previous_start.int_timestamp
            and row["end_timestamp"] <= previous_end.int_timestamp
        ]
        comparison = _build_period_statistics(
            comparison_rows, area, request, comparison_start, comparison_end, include_details=False
        )
        previous = _build_period_statistics(
            previous_rows, area, request, previous_start, previous_end, include_details=False
        )
        if (
            comparison["coverage"]["is_complete"]
            and previous["coverage"]["is_complete"]
            and comparison["average_price"] is not None
            and previous["average_price"] not in (None, 0)
        ):
            change_percent = (
                (comparison["average_price"] - previous["average_price"])
                / abs(previous["average_price"])
                * 100
            )

    response = {
        "area": area.key,
        "range": request.range,
        "start_timestamp": period_start.int_timestamp,
        "end_timestamp": period_end.int_timestamp,
        "comparison_change_percent": change_percent,
        **selected,
    }
    return response


async def get_statistics(
    config: Config,
    area: MarketArea,
    request: PriceStatisticsRequest,
) -> Optional[dict]:
    """Calculate statistics without blocking the API event loop."""
    return await asyncio.to_thread(calculate_statistics, config, area, request)
