import tempfile
import unittest

from datetime import date
from decimal import Decimal
from pathlib import Path

import arrow

from box import Box, BoxList
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch

from awattprice import api
from awattprice import defaults
from awattprice import price_database
from awattprice import price_statistics
from awattprice import prices


AREA = defaults.get_market_area("DE-LU")


def make_config(root: Path) -> Box:
    data_dir = root / "data"
    return Box(
        {
            "paths": {
                "data_dir": data_dir,
                "price_data_dir": data_dir / "price_data",
            }
        }
    )


def price_data(period_start: arrow.Arrow, period_end: arrow.Arrow) -> Box:
    data = Box(
        {
            "source": "ENTSOE",
            "area": AREA.key,
            "display_name": AREA.display_name,
            "entsoe_domain": AREA.entsoe_domain,
            "timezone": AREA.timezone,
            "currency": AREA.currency,
            "resolution": "PT60M",
            "sequence_position": "1",
            "fallback_sequence_positions": [],
            "fallback_price_count": 0,
            "carried_forward_price_count": 0,
        }
    )
    points = []
    cursor = period_start
    boundary = arrow.get("2026-02-01", tzinfo=AREA.timezone)
    while cursor < period_end:
        point = Box()
        point.start_timestamp = cursor
        point.end_timestamp = cursor.shift(hours=+1)
        point.marketprice = prices.MarketPrice(
            Decimal("200") if cursor < boundary else Decimal("100"),
            AREA,
        )
        point.resolution = "PT60M"
        point.sequence_position = "1"
        point.is_fallback = False
        point.is_carried_forward = False
        points.append(point)
        cursor = point.end_timestamp
    data.prices = BoxList(points)
    return data


def remove_local_days(data: Box, days: set[date]) -> None:
    data.prices = BoxList(
        point
        for point in data.prices
        if point.start_timestamp.to(AREA.timezone).date() not in days
    )


class PriceStatisticsTests(unittest.TestCase):
    def test_statistics_are_duration_weighted_and_use_ordered_adjustments(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = make_config(Path(temporary_directory))
            start = arrow.get("2026-01-01", tzinfo=AREA.timezone)
            end = arrow.get("2026-03-01", tzinfo=AREA.timezone)
            price_database.store_dataset(config, AREA.key, "archive:test", price_data(start, end))

            request = price_statistics.PriceStatisticsRequest(
                add_ons=[
                    {"kind": "tax", "value": 0},
                    {"kind": "fixed", "value": 5},
                    {"kind": "percentage", "value": 10},
                ],
            )
            result = price_statistics.calculate_statistics(config, AREA, request, now=end)

            self.assertIsNotNone(result)
            result = result["1mo"]
            self.assertAlmostEqual(result["average_price"], 18.59)
            self.assertAlmostEqual(result["comparison_change_percent"], -41.3194444)
            self.assertEqual(result["distribution"]["cheap_percent"], 100)
            self.assertEqual(result["negative_hours"], 0)
            self.assertTrue(result["coverage"]["is_complete"])
            self.assertEqual(len(result["trend"]), 28)

    def test_two_year_range_omits_comparison(self):
        end = arrow.get("2026-03-01", tzinfo=AREA.timezone)
        period_start = price_statistics.range_start(end, "2yr")

        self.assertIsNone(price_statistics._comparison_periods(period_start, end, "2yr"))

    def test_incomplete_selected_period_returns_no_statistics(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = make_config(Path(temporary_directory))
            end = arrow.get("2026-03-01", tzinfo=AREA.timezone)
            partial_start = arrow.get("2026-02-15", tzinfo=AREA.timezone)
            price_database.store_dataset(
                config,
                AREA.key,
                "archive:partial",
                price_data(partial_start, end),
            )

            result = price_statistics.calculate_statistics(
                config,
                AREA,
                price_statistics.PriceStatisticsRequest(),
                now=end,
            )

            self.assertIsNone(result)

    def test_statistics_accept_at_least_95_percent_with_a_one_day_gap(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = make_config(Path(temporary_directory))
            start = arrow.get("2026-02-01", tzinfo=AREA.timezone)
            end = arrow.get("2026-03-01", tzinfo=AREA.timezone)
            data = price_data(start, end)
            remove_local_days(data, {date(2026, 2, 10)})
            price_database.store_dataset(config, AREA.key, "archive:usable", data)

            result = price_statistics.calculate_statistics(
                config,
                AREA,
                price_statistics.PriceStatisticsRequest(),
                now=end,
            )

            self.assertIsNotNone(result)
            result = result["1mo"]
            self.assertFalse(result["coverage"]["is_complete"])
            self.assertTrue(result["coverage"]["is_usable"])
            self.assertAlmostEqual(result["coverage"]["percent"], 27 / 28 * 100)
            self.assertEqual(result["coverage"]["maximum_gap_seconds"], 24 * 60 * 60)

    def test_statistics_reject_less_than_95_percent(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = make_config(Path(temporary_directory))
            start = arrow.get("2026-02-01", tzinfo=AREA.timezone)
            end = arrow.get("2026-03-01", tzinfo=AREA.timezone)
            data = price_data(start, end)
            remove_local_days(data, {date(2026, 2, 10), date(2026, 2, 20)})
            price_database.store_dataset(config, AREA.key, "archive:insufficient", data)

            result = price_statistics.calculate_statistics(
                config,
                AREA,
                price_statistics.PriceStatisticsRequest(),
                now=end,
            )

            self.assertIsNone(result)

    def test_statistics_reject_gap_longer_than_24_hours(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = make_config(Path(temporary_directory))
            start = arrow.get("2026-02-01", tzinfo=AREA.timezone)
            end = arrow.get("2026-03-01", tzinfo=AREA.timezone)
            data = price_data(start, end)
            remove_local_days(data, {date(2026, 2, 10), date(2026, 2, 11)})
            price_database.store_dataset(config, AREA.key, "archive:long-gap", data)

            result = price_statistics.calculate_statistics(
                config,
                AREA,
                price_statistics.PriceStatisticsRequest(),
                now=end,
            )

            self.assertIsNone(result)

    def test_incomplete_calendar_month_is_excluded_from_cheapest_month(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = make_config(Path(temporary_directory))
            start = arrow.get("2025-03-01", tzinfo=AREA.timezone)
            end = arrow.get("2026-03-01", tzinfo=AREA.timezone)
            data = price_data(start, end)
            remove_local_days(data, {date(2026, 1, 10), date(2026, 1, 20)})
            for point in data.prices:
                local = point.start_timestamp.to(AREA.timezone)
                if local.year == 2026 and local.month == 1:
                    point.marketprice = prices.MarketPrice(Decimal("-1000"), AREA)
            price_database.store_dataset(config, AREA.key, "archive:incomplete-month", data)

            result = price_statistics.calculate_statistics(
                config,
                AREA,
                price_statistics.PriceStatisticsRequest(),
                now=end,
            )

            self.assertIsNotNone(result)
            result = result["1yr"]
            self.assertEqual(result["highlight"]["kind"], "month")
            self.assertEqual(result["highlight"]["value"], 2)

    def test_incomplete_previous_period_only_omits_comparison(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = make_config(Path(temporary_directory))
            start = arrow.get("2026-02-01", tzinfo=AREA.timezone)
            end = arrow.get("2026-03-01", tzinfo=AREA.timezone)
            price_database.store_dataset(
                config,
                AREA.key,
                "archive:current",
                price_data(start, end),
            )

            result = price_statistics.calculate_statistics(
                config,
                AREA,
                price_statistics.PriceStatisticsRequest(),
                now=end,
            )

            self.assertIsNotNone(result)
            result = result["1mo"]
            self.assertIsNone(result["comparison_change_percent"])
            self.assertTrue(result["coverage"]["is_complete"])

    def test_sqlite_keeps_primary_interval_when_a_fallback_import_arrives_later(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = make_config(Path(temporary_directory))
            start = arrow.get("2026-02-01", tzinfo=AREA.timezone)
            primary = price_data(start, start.shift(hours=+1))
            price_database.store_dataset(config, AREA.key, "archive:primary", primary)

            fallback = price_data(start, start.shift(hours=+1))
            fallback.prices[0].marketprice = prices.MarketPrice(Decimal("999"), AREA)
            fallback.prices[0].is_fallback = True
            price_database.store_dataset(config, AREA.key, "archive:fallback", fallback)

            stored = price_database.load_points(
                config,
                AREA.key,
                start.int_timestamp,
                start.shift(hours=+1).int_timestamp,
            )
            self.assertEqual(stored[0]["marketprice"], "100")
            self.assertEqual(stored[0]["is_fallback"], 0)

    def test_statistics_endpoint_is_additive_and_validates_area(self):
        expected = {"1mo": {"area": "DE-LU", "range": "1mo", "average_price": 12.3}}
        client = TestClient(api.app)
        with patch.object(
            api.price_statistics,
            "get_statistics",
            new=AsyncMock(return_value=expected),
        ) as get_statistics:
            response = client.post(
                "/prices/DE-LU/statistics",
                json={"add_ons": [{"kind": "fixed", "value": 4.2}]},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), expected)
        get_statistics.assert_awaited_once()
        self.assertEqual(client.post("/prices/unknown/statistics", json={}).status_code, 404)
