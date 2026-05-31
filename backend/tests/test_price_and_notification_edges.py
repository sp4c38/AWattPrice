import asyncio
import tempfile
import unittest

from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

import arrow

from box import Box
from box import BoxList

from awattprice import defaults
from awattprice import prices
from awattprice_refresher import prices as price_refresher
from awattprice_notifications import payloads
from awattprice_notifications import prices as notification_prices
from awattprice_notifications import rules as notification_rules


AREA = defaults.get_market_area("DE-LU")


class FakeTimestamp:
    def __init__(self, hour, int_timestamp):
        self.hour = hour
        self.int_timestamp = int_timestamp

    def format(self, format_string):
        if format_string == "H":
            return str(self.hour)
        return f"{self.hour}:00"


class FakeMarketPrice:
    def __init__(self, untaxed):
        self.untaxed = Decimal(str(untaxed))

    def subunit_kwh(self, taxed=False, round_=True):
        value = self.untaxed * Decimal("1.19") if taxed else self.untaxed
        return value.quantize(Decimal("0.01")) if round_ else value


def profile(active_below=True, active_above=True, active_summary=True):
    return Box(
        {
            "token": "abc123",
            "general": {
                "area": "DE-LU",
                "tax": True,
                "base_fee": 2,
                "percentage_add_on": 10,
            },
            "rules": {
                "price_below": {"active": active_below, "threshold": 20},
                "price_above": {"active": active_above, "threshold": 50},
                "daily_summary": {"active": active_summary},
            },
        }
    )


def make_test_config(root: Path) -> Box:
    config = Box()
    config.paths = Box()
    config.paths.price_data_dir = root / "price_data"
    config.paths.price_data_dir.mkdir(parents=True)
    return config


def price_point(hour: int, value: Decimal | str | int):
    return Box(
        {
            "start_timestamp": FakeTimestamp(hour, hour * 3600),
            "end_timestamp": FakeTimestamp(hour + 1, (hour + 1) * 3600),
            "marketprice": FakeMarketPrice(value),
        }
    )


def refresh_price_data(point_specs):
    data = Box({"prices": BoxList()})
    for point_spec in point_specs:
        if len(point_spec) == 5:
            start_time, end_time, value, sequence_position, is_fallback = point_spec
            is_interpolated = False
        else:
            start_time, end_time, value, sequence_position, is_fallback, is_interpolated = point_spec
        data.prices.append(
            Box(
                {
                    "start_timestamp": arrow.get(start_time),
                    "end_timestamp": arrow.get(end_time),
                    "marketprice": prices.MarketPrice(Decimal(str(value)), AREA),
                    "sequence_position": sequence_position,
                    "is_fallback": is_fallback,
                    "is_interpolated": is_interpolated,
                }
            )
        )
    return data


def notification_price_data(day: str, resolution: str = "PT60M", fallback_indexes=None, interpolated_indexes=None):
    fallback_indexes = set(fallback_indexes or [])
    interpolated_indexes = set(interpolated_indexes or [])
    interval_seconds = prices.resolution_to_seconds(resolution)
    start = arrow.get(f"{day}T00:00:00+02:00")
    point_count = int(24 * 60 * 60 / interval_seconds)
    return Box(
        {
            "area": "DE-LU",
            "resolution": resolution,
            "prices": BoxList(
                [
                    Box(
                        {
                            "start_timestamp": start.shift(seconds=index * interval_seconds),
                            "end_timestamp": start.shift(seconds=(index + 1) * interval_seconds),
                            "is_fallback": index in fallback_indexes,
                            "is_interpolated": index in interpolated_indexes,
                        }
                    )
                    for index in range(point_count)
                ]
            ),
        }
    )


class PriceCacheAndConversionTests(unittest.TestCase):
    def test_area_file_key_normalizes_symbols_for_cache_paths(self):
        self.assertEqual(prices.area_file_key("DE-LU"), "de_lu")
        self.assertEqual(prices.area_file_key("IE(SEM)"), "ie_sem")
        self.assertEqual(prices.history_date_file_key(arrow.get("2026-05-24").date()), "2026-05-24")

    def test_market_price_uses_area_tax_and_subunit_conversion(self):
        market_price = prices.MarketPrice(Decimal("100"), AREA)

        self.assertEqual(market_price.taxed, Decimal("119.00"))
        self.assertEqual(market_price.subunit_kwh(), Decimal("10.0"))
        self.assertEqual(market_price.subunit_kwh(taxed=True), Decimal("11.900"))
        self.assertEqual(market_price.subunit_kwh(taxed=True, round_=True), Decimal("11.90"))

    def test_check_data_new_compares_latest_end_timestamp(self):
        old_data = refresh_price_data([
            ("2026-05-24T09:00:00+02:00", "2026-05-24T10:00:00+02:00", 10, "1", False),
        ])
        same_data = refresh_price_data([
            ("2026-05-24T09:00:00+02:00", "2026-05-24T10:00:00+02:00", 10, "1", False),
        ])
        new_data = refresh_price_data([
            ("2026-05-24T10:00:00+02:00", "2026-05-24T11:00:00+02:00", 10, "1", False),
        ])

        self.assertFalse(price_refresher.check_data_new(old_data, same_data))
        self.assertTrue(price_refresher.check_data_new(old_data, new_data))
        self.assertTrue(price_refresher.check_data_new(None, same_data))

    def test_check_data_new_accepts_more_complete_payload_with_same_latest_end(self):
        old_data = refresh_price_data([
            ("2026-05-24T09:00:00+02:00", "2026-05-24T10:00:00+02:00", 10, "1", False),
            ("2026-05-24T11:00:00+02:00", "2026-05-24T12:00:00+02:00", 30, "1", False),
        ])
        completed_data = refresh_price_data([
            ("2026-05-24T09:00:00+02:00", "2026-05-24T10:00:00+02:00", 10, "1", False),
            ("2026-05-24T10:00:00+02:00", "2026-05-24T11:00:00+02:00", 20, "2", True),
            ("2026-05-24T11:00:00+02:00", "2026-05-24T12:00:00+02:00", 30, "1", False),
        ])

        self.assertTrue(price_refresher.check_data_new(old_data, completed_data))
        self.assertFalse(price_refresher.check_data_new(completed_data, old_data))

    def test_check_data_new_replaces_fallback_with_preferred_sequence(self):
        fallback_data = refresh_price_data([
            ("2026-05-24T09:00:00+02:00", "2026-05-24T10:00:00+02:00", 10, "1", False),
            ("2026-05-24T10:00:00+02:00", "2026-05-24T11:00:00+02:00", 200, "2", True),
            ("2026-05-24T11:00:00+02:00", "2026-05-24T12:00:00+02:00", 30, "1", False),
        ])
        preferred_data = refresh_price_data([
            ("2026-05-24T09:00:00+02:00", "2026-05-24T10:00:00+02:00", 10, "1", False),
            ("2026-05-24T10:00:00+02:00", "2026-05-24T11:00:00+02:00", 20, "1", False),
            ("2026-05-24T11:00:00+02:00", "2026-05-24T12:00:00+02:00", 30, "1", False),
        ])

        self.assertTrue(price_refresher.check_data_new(fallback_data, preferred_data))
        self.assertFalse(price_refresher.check_data_new(preferred_data, fallback_data))

    def test_check_data_new_replaces_interpolation_with_source_price(self):
        interpolated_data = refresh_price_data([
            ("2026-05-24T09:00:00+02:00", "2026-05-24T10:00:00+02:00", 10, "1", False),
            ("2026-05-24T10:00:00+02:00", "2026-05-24T11:00:00+02:00", 20, "interpolated", False, True),
            ("2026-05-24T11:00:00+02:00", "2026-05-24T12:00:00+02:00", 30, "1", False),
        ])
        fallback_data = refresh_price_data([
            ("2026-05-24T09:00:00+02:00", "2026-05-24T10:00:00+02:00", 10, "1", False),
            ("2026-05-24T10:00:00+02:00", "2026-05-24T11:00:00+02:00", 200, "2", True),
            ("2026-05-24T11:00:00+02:00", "2026-05-24T12:00:00+02:00", 30, "1", False),
        ])

        self.assertTrue(price_refresher.check_data_new(interpolated_data, fallback_data))
        self.assertFalse(price_refresher.check_data_new(fallback_data, interpolated_data))

    def test_current_price_fallback_rejects_expired_cache(self):
        async def run_test():
            cached_data = Box(
                {
                    "prices": [
                        Box({"end_timestamp": arrow.get("2026-05-23T23:00:00+02:00")}),
                    ]
                }
            )

            with patch("awattprice.prices.arrow.now", return_value=arrow.get("2026-05-24T12:00:00+02:00")):
                self.assertFalse(prices.has_current_price_points(cached_data, AREA))

        asyncio.run(run_test())

    def test_history_cache_path_keeps_areas_and_dates_separate(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = make_test_config(Path(temp_dir))

            first_path = prices.get_history_data_path("DE-LU", arrow.get("2026-05-23").date(), config)
            second_path = prices.get_history_data_path("AT", arrow.get("2026-05-23").date(), config)

            self.assertIn("de_lu-2026-05-23", first_path.name)
            self.assertIn("at-2026-05-23", second_path.name)
            self.assertNotEqual(first_path, second_path)


class NotificationPayloadEdgeTests(unittest.TestCase):
    def test_adjusted_price_respects_add_on_order(self):
        raw_profile = profile()
        raw_profile.general.fixed_add_on = 2
        raw_profile.general.monthly_fixed_cost_add_on = 1
        raw_profile.general.percentage_add_on = Decimal("10")
        raw_profile.general.add_on_order = ["fixed", "monthly", "percentage"]
        price = price_point(1, 10)

        self.assertEqual(payloads.adjusted_price(price, raw_profile), Decimal("16.390"))

        raw_profile.general.add_on_order = ["percentage", "fixed", "monthly"]
        self.assertEqual(payloads.adjusted_price(price, raw_profile), Decimal("16.090"))

    def test_format_price_timestamp_uses_minutes_for_quarter_hour_resolution(self):
        timestamp = FakeTimestamp(7, 7 * 3600)

        self.assertEqual(payloads.format_price_timestamp(timestamp, "PT60M"), "7")
        self.assertEqual(payloads.format_price_timestamp(timestamp, "PT15M"), "7:00")

    def test_active_rule_types_preserves_delivery_order(self):
        raw_profile = profile(active_below=True, active_above=False, active_summary=True)

        self.assertEqual(payloads.active_rule_types(raw_profile), ["price_below", "daily_summary"])

    def test_notification_price_collection_filters_areas_without_complete_tomorrow(self):
        price_data = Box({"DE-LU": Box({"area": "DE-LU", "resolution": "PT60M", "prices": []})})

        self.assertEqual(notification_prices.get_notifiable_areas_prices(price_data), {})

    def test_notification_prices_allow_small_fallback_budget(self):
        allowed_prices = notification_price_data("2026-05-26", fallback_indexes=[0, 1])
        excessive_fallback_prices = notification_price_data("2026-05-26", fallback_indexes=[0, 1, 2])
        allowed_quarter_hour_prices = notification_price_data(
            "2026-05-26",
            resolution="PT15M",
            fallback_indexes=range(8),
        )
        excessive_quarter_hour_prices = notification_price_data(
            "2026-05-26",
            resolution="PT15M",
            fallback_indexes=range(9),
        )

        with patch(
            "awattprice_notifications.rules.arrow.now",
            return_value=arrow.get("2026-05-25T14:00:00+02:00"),
        ):
            self.assertIsNotNone(notification_rules.get_notifiable_prices(allowed_prices))
            self.assertIsNone(notification_rules.get_notifiable_prices(excessive_fallback_prices))
            self.assertIsNotNone(notification_rules.get_notifiable_prices(allowed_quarter_hour_prices))
            self.assertIsNone(notification_rules.get_notifiable_prices(excessive_quarter_hour_prices))

    def test_notification_prices_reject_interpolated_points(self):
        interpolated_prices = notification_price_data("2026-05-26", interpolated_indexes=[12])

        with patch(
            "awattprice_notifications.rules.arrow.now",
            return_value=arrow.get("2026-05-25T14:00:00+02:00"),
        ):
            self.assertIsNone(notification_rules.get_notifiable_prices(interpolated_prices))

    def test_price_refresh_freshness_allows_recent_updates_only(self):
        last_update = arrow.get("2026-05-25T15:00:00+02:00")

        self.assertTrue(
            notification_rules.check_price_update_fresh(
                last_update,
                "DE-LU",
                arrow.get("2026-05-25T17:30:00+02:00"),
            )
        )
        self.assertFalse(
            notification_rules.check_price_update_fresh(
                last_update,
                "DE-LU",
                arrow.get("2026-05-25T22:00:00+02:00"),
            )
        )
        self.assertFalse(
            notification_rules.check_price_update_fresh(
                None,
                "DE-LU",
                arrow.get("2026-05-25T15:00:00+02:00"),
            )
        )


if __name__ == "__main__":
    unittest.main()
