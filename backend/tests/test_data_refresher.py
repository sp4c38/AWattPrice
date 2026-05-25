import asyncio
import tempfile
import unittest

from decimal import Decimal
from pathlib import Path
from unittest.mock import AsyncMock
from unittest.mock import patch

import arrow

from box import Box
from box import BoxList

from awattprice import cache_status
from awattprice import defaults
from awattprice import generation_mix
from awattprice import prices
from awattprice import utils
from awattprice_refresher import service as data_refresher


AREA = defaults.get_market_area("DE-LU")


def test_config(root: Path) -> Box:
    config = Box()
    config.paths = Box()
    config.paths.data_dir = root
    config.paths.price_data_dir = root / "price_data"
    config.paths.generation_data_dir = root / "generation_data"
    config.paths.price_data_dir.mkdir(parents=True)
    config.paths.generation_data_dir.mkdir(parents=True)
    return config


def price_data_for(end_time: str) -> Box:
    point = Box()
    point.start_timestamp = arrow.get("2026-05-25T00:00:00+02:00")
    point.end_timestamp = arrow.get(end_time)
    point.marketprice = prices.MarketPrice(Decimal("10"), AREA)
    return Box(
        {
            "source": "ENTSOE",
            "area": AREA.key,
            "display_name": AREA.display_name,
            "entsoe_domain": AREA.entsoe_domain,
            "timezone": AREA.timezone,
            "currency": AREA.currency,
            "resolution": "PT60M",
            "sequence_position": "1",
            "prices": BoxList([point]),
        }
    )


class RefresherStatePersistenceTests(unittest.TestCase):
    def test_load_state_returns_fresh_state_when_no_file_exists(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = test_config(Path(temp_dir))
            state = data_refresher.load_state(config)

        self.assertIsNone(state.current_prices)
        self.assertIsNone(state.price_history)
        self.assertIsNone(state.generation_mix)
        self.assertIsNone(state.cleanup)

    def test_save_and_load_state_roundtrip(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = test_config(Path(temp_dir))

            original = data_refresher.RefresherState()
            original.current_prices = arrow.get("2026-05-25T10:00:00+00:00")
            original.price_history = arrow.get("2026-05-25T08:00:00+00:00")
            original.generation_mix = arrow.get("2026-05-25T09:30:00+00:00")
            original.cleanup = None

            data_refresher.save_state(original, config)
            loaded = data_refresher.load_state(config)

        self.assertEqual(loaded.current_prices.int_timestamp, original.current_prices.int_timestamp)
        self.assertEqual(loaded.price_history.int_timestamp, original.price_history.int_timestamp)
        self.assertEqual(loaded.generation_mix.int_timestamp, original.generation_mix.int_timestamp)
        self.assertIsNone(loaded.cleanup)

    def test_load_state_recovers_from_corrupt_file(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = test_config(Path(temp_dir))
            (Path(temp_dir) / "refresher-state.json").write_text("not valid json{{{")

            state = data_refresher.load_state(config)

        self.assertIsNone(state.current_prices)
        self.assertIsNone(state.price_history)


class DataRefresherScheduleTests(unittest.TestCase):
    def test_berlin_fast_window_uses_ten_minute_interval(self):
        fast_time = arrow.get("2026-05-25T13:30:00+02:00")
        slow_time = arrow.get("2026-05-25T15:00:00+02:00")

        self.assertTrue(data_refresher.fast_price_poll_window(fast_time))
        self.assertEqual(
            data_refresher.current_price_poll_interval(fast_time),
            10 * 60,
        )
        self.assertFalse(data_refresher.fast_price_poll_window(slow_time))
        self.assertEqual(
            data_refresher.current_price_poll_interval(slow_time),
            60 * 60,
        )

    def test_current_price_refresh_skips_when_tomorrow_is_cached(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = test_config(Path(temp_dir))
                cached_data = price_data_for("2026-05-27T00:00:00+02:00")
                await prices.store_data(cached_data, AREA.key, config)

                with (
                    patch(
                        "awattprice_refresher.service.arrow.now",
                        return_value=arrow.get("2026-05-25T13:10:00+02:00"),
                    ),
                    patch(
                        "awattprice_refresher.service.prices_refresher.refresh_current_prices",
                        new=AsyncMock(),
                    ) as refresh,
                ):
                    await data_refresher.refresh_current_prices_for_area(AREA, config)

                refresh.assert_not_awaited()

        asyncio.run(run_test())

    def test_run_cycle_returns_monitoring_summary(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = test_config(Path(temp_dir))
                state = data_refresher.RefresherState()

                with (
                    patch("awattprice_refresher.service.defaults.list_market_areas", return_value=[AREA]),
                    patch("awattprice_refresher.service.run_bounded", new=AsyncMock()) as run_bounded,
                    patch("awattprice_refresher.service.prune_cache", new=AsyncMock(return_value=4)),
                ):
                    result = await data_refresher.run_cycle(
                        config,
                        state,
                        arrow.get("2026-05-25T13:30:00+02:00"),
                    )

            self.assertEqual(run_bounded.await_count, 3)
            self.assertEqual(result["area_count"], 1)
            self.assertEqual(result["current_prices"], "ran")
            self.assertEqual(result["price_history"], "ran")
            self.assertEqual(result["generation_mix"], "ran")
            self.assertEqual(result["pruned_count"], 4)

        asyncio.run(run_test())

    def test_monitoring_message_includes_cycle_status(self):
        message = data_refresher.monitoring_message(
            {
                "area_count": 45,
                "current_prices": "ran",
                "price_history": "skipped",
                "generation_mix": "ran",
                "pruned_count": 2,
            }
        )

        self.assertIn("areas=45", message)
        self.assertIn("current_prices=ran", message)
        self.assertIn("price_history=skipped", message)
        self.assertIn("generation_mix=ran", message)
        self.assertIn("pruned=2", message)


class DataRefresherCleanupTests(unittest.TestCase):
    def test_history_prune_keeps_only_latest_five_completed_berlin_days(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = test_config(Path(temp_dir))
                retained_data = price_data_for("2026-05-24T01:00:00+02:00")
                old_data = price_data_for("2026-05-18T01:00:00+02:00")

                await prices.store_history_data(retained_data, AREA.key, arrow.get("2026-05-24").date(), config)
                await prices.store_history_data(old_data, AREA.key, arrow.get("2026-05-18").date(), config)

                pruned = data_refresher.prune_history_payloads(
                    config,
                    arrow.get("2026-05-25T12:00:00+02:00"),
                )

                self.assertEqual(pruned, 1)
                self.assertTrue(
                    prices.get_history_data_path(AREA.key, arrow.get("2026-05-24").date(), config).exists()
                )
                self.assertFalse(
                    prices.get_history_data_path(AREA.key, arrow.get("2026-05-18").date(), config).exists()
                )

        asyncio.run(run_test())

    def test_generation_prune_trims_old_points_but_keeps_recent_payload(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = test_config(Path(temp_dir))
                old_point = Box(
                    {
                        "start_timestamp": arrow.get("2026-05-10T00:00:00+02:00"),
                        "end_timestamp": arrow.get("2026-05-10T01:00:00+02:00"),
                        "raw_production_type": "B16",
                        "raw_production_name": "Solar",
                        "category": "solar",
                        "quantity_mw": Decimal("10"),
                        "is_renewable": True,
                    }
                )
                recent_point = Box(
                    {
                        "start_timestamp": arrow.get("2026-05-24T00:00:00+02:00"),
                        "end_timestamp": arrow.get("2026-05-24T01:00:00+02:00"),
                        "raw_production_type": "B16",
                        "raw_production_name": "Solar",
                        "category": "solar",
                        "quantity_mw": Decimal("10"),
                        "is_renewable": True,
                    }
                )
                data = Box(
                    {
                        "source": "ENTSOE",
                        "area": AREA.key,
                        "display_name": AREA.display_name,
                        "entsoe_domain": AREA.entsoe_domain,
                        "timezone": AREA.timezone,
                        "resolution": "PT60M",
                        "updated_at": arrow.get("2026-05-24T01:00:00+02:00"),
                        "generation_points": BoxList([old_point, recent_point]),
                    }
                )
                await generation_mix.store_data(data, AREA.key, config)

                pruned = await data_refresher.prune_generation_payloads(
                    config,
                    arrow.get("2026-05-25T12:00:00+02:00"),
                )
                stored_data = await generation_mix.get_stored_data(AREA.key, config)

                self.assertEqual(pruned, 1)
                self.assertEqual(len(stored_data.generation_points), 1)
                self.assertEqual(stored_data.generation_points[0].start_timestamp, recent_point.start_timestamp)

        asyncio.run(run_test())

    def test_cache_status_reports_pruned_count(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = test_config(Path(temp_dir))
                cache_status.record_prune_result(config, 3)

                response = await cache_status.cache_status_response(config)

                self.assertEqual(response.cleanup.pruned_count, 3)

        asyncio.run(run_test())


class AtomicCacheWriteTests(unittest.TestCase):
    def test_atomic_write_keeps_old_payload_until_replace(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "cache.pickle"
            path.write_bytes(b"old payload")
            real_replace = utils.os.replace
            observed = {}

            def observe_replace(temp_path, target_path):
                observed["temp_payload"] = Path(temp_path).read_bytes()
                observed["target_payload_before_replace"] = Path(target_path).read_bytes()
                real_replace(temp_path, target_path)

            with patch("awattprice.utils.os.replace", side_effect=observe_replace):
                utils.atomic_write_bytes(path, b"new payload")

            self.assertEqual(observed["temp_payload"], b"new payload")
            self.assertEqual(observed["target_payload_before_replace"], b"old payload")
            self.assertEqual(path.read_bytes(), b"new payload")


if __name__ == "__main__":
    unittest.main()
