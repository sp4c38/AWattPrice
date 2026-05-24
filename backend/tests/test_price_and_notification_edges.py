import asyncio
import tempfile
import unittest

from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

import arrow

from box import Box

from awattprice import defaults
from awattprice import prices
from awattprice_notifications import payloads
from awattprice_notifications import prices as notification_prices


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
        old_data = Box({"prices": [Box({"end_timestamp": arrow.get("2026-05-24T10:00:00+02:00")})]})
        same_data = Box({"prices": [Box({"end_timestamp": arrow.get("2026-05-24T10:00:00+02:00")})]})
        new_data = Box({"prices": [Box({"end_timestamp": arrow.get("2026-05-24T11:00:00+02:00")})]})

        self.assertFalse(prices.check_data_new(old_data, same_data))
        self.assertTrue(prices.check_data_new(old_data, new_data))
        self.assertTrue(prices.check_data_new(None, same_data))

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


if __name__ == "__main__":
    unittest.main()
