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


def make_config(root: Path) -> Box:
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


def complete_hourly_price_data_for_day(day: str) -> Box:
    day_start = arrow.get(day, "YYYY-MM-DD", tzinfo=AREA.timezone)
    points = BoxList()
    for hour in range(24):
        point = Box()
        point.start_timestamp = day_start.shift(hours=+hour)
        point.end_timestamp = day_start.shift(hours=+(hour + 1))
        point.marketprice = prices.MarketPrice(Decimal(str(10 + hour)), AREA)
        point.sequence_position = "1"
        point.is_fallback = False
        points.append(point)

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
            "fallback_sequence_positions": [],
            "fallback_price_count": 0,
            "prices": points,
        }
    )


class RefresherStatePersistenceTests(unittest.TestCase):
    def test_load_state_returns_fresh_state_when_no_file_exists(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = make_config(Path(temp_dir))
            state = data_refresher.load_state(config)

        self.assertIsNone(state.current_prices)
        self.assertIsNone(state.price_history)
        self.assertIsNone(state.generation_mix)
        self.assertIsNone(state.cleanup)

    def test_save_and_load_state_roundtrip(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = make_config(Path(temp_dir))

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
            config = make_config(Path(temp_dir))
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
                config = make_config(Path(temp_dir))
                cached_data = complete_hourly_price_data_for_day("2026-05-26")
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

    def test_current_price_refresh_runs_when_tomorrow_has_gaps(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
                cached_data = price_data_for("2026-05-27T00:00:00+02:00")
                await prices.store_data(cached_data, AREA.key, config)

                with (
                    patch(
                        "awattprice_refresher.service.arrow.now",
                        return_value=arrow.get("2026-05-25T13:10:00+02:00"),
                    ),
                    patch(
                        "awattprice_refresher.service.prices_refresher.refresh_current_prices",
                        new=AsyncMock(return_value=cached_data),
                    ) as refresh,
                ):
                    await data_refresher.refresh_current_prices_for_area(AREA, config)

                refresh.assert_awaited_once()

        asyncio.run(run_test())

    def test_run_cycle_returns_monitoring_summary(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
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
            self.assertEqual(run_bounded.await_args_list[0].kwargs, {})
            self.assertEqual(run_bounded.await_args_list[1].kwargs, {})
            self.assertEqual(
                run_bounded.await_args_list[2].kwargs,
                {"concurrency": data_refresher.defaults.REFRESHER_GENERATION_CONCURRENCY},
            )
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
                config = make_config(Path(temp_dir))
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

    def test_generation_prune_deletes_legacy_and_unsupported_payloads(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
                generation_points = BoxList()
                for hour in range(2):
                    generation_points.append(
                        Box(
                            {
                                "start_timestamp": arrow.get("2026-05-24T00:00:00+02:00").shift(hours=+hour),
                                "end_timestamp": arrow.get("2026-05-24T01:00:00+02:00").shift(hours=+hour),
                                "raw_production_type": "B16",
                                "raw_production_name": "Solar",
                                "category": "solar",
                                "quantity_mw": Decimal("10"),
                                "is_renewable": True,
                            }
                        )
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
                        "generation_points": generation_points,
                    }
                )
                await generation_mix.store_data(data, AREA.key, config)
                retained_json_path = generation_mix.get_history_response_data_path(
                    AREA.key,
                    defaults.GENERATION_RETENTION_HOURS,
                    config,
                )
                retained_metadata_path = generation_mix.get_metadata_path(AREA.key, config)
                legacy_pickle_path = config.paths.generation_data_dir / "generation-data-DE-LU.pickle"
                legacy_update_path = config.paths.generation_data_dir / "generation-update-ts-DE-LU.info"
                unsupported_json_path = config.paths.generation_data_dir / "generation-history-OLD-168h.json"
                unsupported_metadata_path = config.paths.generation_data_dir / "generation-meta-OLD.json"
                unsupported_hours_path = config.paths.generation_data_dir / "generation-history-DE-LU-24h.json"
                legacy_pickle_path.write_bytes(b"old pickle")
                legacy_update_path.write_text("123")
                unsupported_json_path.write_text("{}")
                unsupported_metadata_path.write_text("{}")
                unsupported_hours_path.write_text("{}")

                pruned = await data_refresher.prune_generation_payloads(
                    config,
                    arrow.get("2026-05-25T12:00:00+02:00"),
                )

                self.assertEqual(pruned, 5)
                self.assertTrue(retained_json_path.exists())
                self.assertTrue(retained_metadata_path.exists())
                self.assertFalse(legacy_pickle_path.exists())
                self.assertFalse(legacy_update_path.exists())
                self.assertFalse(unsupported_json_path.exists())
                self.assertFalse(unsupported_metadata_path.exists())
                self.assertFalse(unsupported_hours_path.exists())

        asyncio.run(run_test())

    def test_cache_status_reports_pruned_count(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
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
