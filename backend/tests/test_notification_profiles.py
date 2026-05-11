import tempfile
import unittest

from decimal import Decimal
from pathlib import Path

from box import Box

from awattprice import notification_profiles
from awattprice_notifications.price_below import defaults
from awattprice_notifications.price_below import notifications


class FakeTimestamp:
    def __init__(self, hour, int_timestamp):
        self.hour = hour
        self.int_timestamp = int_timestamp

    def format(self, format_string):
        if format_string == "H":
            return str(self.hour)
        return f"{self.hour}:00"


class FakeMarketPrice:
    area = "DE-LU"

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


def price(hour, value):
    return Box(
        {
            "start_timestamp": FakeTimestamp(hour, hour * 3600),
            "end_timestamp": FakeTimestamp(hour + 1, (hour + 1) * 3600),
            "marketprice": FakeMarketPrice(value),
        }
    )


def notifiable_prices():
    return Box({"data": {"resolution": "PT60M", "prices": [price(1, 10), price(2, 30), price(3, 45)]}})


class NotificationProfileTests(unittest.TestCase):
    def test_parse_profile_normalizes_decimals(self):
        parsed = notification_profiles.parse_notification_profile_body(profile())

        self.assertIsNotNone(parsed)
        self.assertEqual(parsed.general.area, "DE-LU")
        self.assertEqual(parsed.general.base_fee, Decimal("2"))
        self.assertEqual(parsed.general.percentage_add_on, Decimal("10"))

    def test_parse_rejects_active_threshold_rule_without_threshold(self):
        raw_profile = profile()
        raw_profile.rules.price_below.threshold = None

        self.assertIsNone(notification_profiles.parse_notification_profile_body(raw_profile))

    def test_parse_accepts_missing_inactive_threshold(self):
        raw_profile = profile(active_below=False, active_above=False, active_summary=True)
        del raw_profile.rules.price_below["threshold"]
        del raw_profile.rules.price_above["threshold"]

        parsed = notification_profiles.parse_notification_profile_body(raw_profile)

        self.assertIsNotNone(parsed)
        self.assertIsNone(parsed.rules.price_below.threshold)
        self.assertIsNone(parsed.rules.price_above.threshold)
        self.assertTrue(parsed.rules.daily_summary.active)

    def test_store_creates_replaces_and_persists_disabled_rules(self):
        with tempfile.TemporaryDirectory() as directory:
            store = notification_profiles.NotificationProfileStore(Path(directory) / "profiles.json")
            first_profile = notification_profiles.parse_notification_profile_body(profile())
            store.save_profile(first_profile)

            replacement = profile(active_below=False, active_above=False, active_summary=False)
            replacement.rules.price_below.threshold = None
            replacement.rules.price_above.threshold = None
            parsed_replacement = notification_profiles.parse_notification_profile_body(replacement)
            store.save_profile(parsed_replacement)

            document = store.load()
            self.assertEqual(document["schema_version"], 1)
            self.assertEqual(len(document["profiles"]), 1)
            stored_profile = document["profiles"]["abc123"]
            self.assertFalse(stored_profile["rules"]["price_below"]["active"])
            self.assertFalse(stored_profile["rules"]["price_above"]["active"])
            self.assertFalse(stored_profile["rules"]["daily_summary"]["active"])

    def test_store_handles_missing_and_corrupted_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profiles.json"
            store = notification_profiles.NotificationProfileStore(path)

            self.assertEqual(store.load(), {"schema_version": 1, "profiles": {}})

            path.write_text("{not json", encoding="utf-8")
            with self.assertRaises(ValueError):
                store.load()


class NotificationMatchingTests(unittest.TestCase):
    def test_selected_prices_include_tax_and_add_ons(self):
        parsed_profile = notification_profiles.parse_notification_profile_body(profile())
        prices = notifiable_prices()

        below_prices = notifications.selected_prices_for_rule(parsed_profile, "price_below", prices)
        above_prices = notifications.selected_prices_for_rule(parsed_profile, "price_above", prices)

        self.assertEqual([item.start_timestamp.hour for item in below_prices], [1])
        self.assertEqual([item.start_timestamp.hour for item in above_prices], [3])

    def test_construct_payloads_for_all_rules(self):
        parsed_profile = notification_profiles.parse_notification_profile_body(profile())
        prices = notifiable_prices()

        below_payload = notifications.construct_notification(
            parsed_profile,
            "price_below",
            notifications.selected_prices_for_rule(parsed_profile, "price_below", prices),
            prices,
        )
        above_payload = notifications.construct_notification(
            parsed_profile,
            "price_above",
            notifications.selected_prices_for_rule(parsed_profile, "price_above", prices),
            prices,
        )
        summary_payload = notifications.construct_notification(
            parsed_profile,
            "daily_summary",
            notifications.selected_prices_for_rule(parsed_profile, "daily_summary", prices),
            prices,
        )

        self.assertEqual(below_payload.aps.alert["loc-key"], "notifications.price_below.body.single")
        self.assertEqual(above_payload.aps.alert["loc-key"], "notifications.price_above.body.single")
        self.assertEqual(summary_payload.aps.alert["loc-key"], "notifications.daily_summary.body")

    def test_get_notifiable_prices_uses_market_area_metadata(self):
        prices = Box(
            {
                "area": "DE-LU",
                "resolution": "PT60M",
                "prices": [],
            }
        )

        self.assertIsNone(defaults.get_notifiable_prices(prices))


if __name__ == "__main__":
    unittest.main()
