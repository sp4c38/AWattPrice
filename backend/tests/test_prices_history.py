import asyncio
import tempfile
import unittest

from concurrent.futures import ThreadPoolExecutor
from datetime import date
from decimal import Decimal
from pathlib import Path
from unittest.mock import AsyncMock
from unittest.mock import patch

import arrow

from box import Box
from fastapi.testclient import TestClient

from awattprice import api
from awattprice import defaults
from awattprice import price_database
from awattprice import prices
from awattprice_refresher import price_history_backfill
from awattprice_refresher import prices as price_refresher


AREA = defaults.get_market_area("DE-LU")


def price_xml(resolution: str = "PT60M") -> bytes:
    if resolution == "PT15M":
        period_end = "2026-05-13T01:00Z"
        points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>2</position><price.amount>20</price.amount></Point>
      <Point><position>3</position><price.amount>30</price.amount></Point>
      <Point><position>4</position><price.amount>40</price.amount></Point>
"""
    else:
        period_end = "2026-05-13T02:00Z"
        points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>2</position><price.amount>20</price.amount></Point>
"""

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Publication_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3">
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>1</classificationSequence_AttributeInstanceComponent.position>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>{period_end}</end>
      </timeInterval>
      <resolution>{resolution}</resolution>
{points}
    </Period>
  </TimeSeries>
</Publication_MarketDocument>
""".encode()


def dst_day_price_xml(period_start: str, period_end: str) -> bytes:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Publication_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3">
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>1</classificationSequence_AttributeInstanceComponent.position>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>{period_start}</start>
        <end>{period_end}</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><price.amount>10</price.amount></Point>
    </Period>
  </TimeSeries>
</Publication_MarketDocument>
""".encode()


def unclassified_multi_series_xml() -> bytes:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Publication_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3">
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>2026-05-13T02:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>2</position><price.amount>20</price.amount></Point>
    </Period>
  </TimeSeries>
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-13T02:00Z</start>
        <end>2026-05-13T04:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><price.amount>30</price.amount></Point>
      <Point><position>2</position><price.amount>40</price.amount></Point>
    </Period>
  </TimeSeries>
</Publication_MarketDocument>
""".encode()


def classified_multi_sequence_xml(sequence_one_points: str) -> bytes:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Publication_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3">
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>2</classificationSequence_AttributeInstanceComponent.position>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>2026-05-13T01:00Z</end>
      </timeInterval>
      <resolution>PT15M</resolution>
      <Point><position>1</position><price.amount>100</price.amount></Point>
      <Point><position>2</position><price.amount>200</price.amount></Point>
      <Point><position>3</position><price.amount>300</price.amount></Point>
      <Point><position>4</position><price.amount>400</price.amount></Point>
    </Period>
  </TimeSeries>
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>1</classificationSequence_AttributeInstanceComponent.position>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>2026-05-13T01:00Z</end>
      </timeInterval>
      <resolution>PT15M</resolution>
{sequence_one_points}
    </Period>
  </TimeSeries>
</Publication_MarketDocument>
""".encode()


def classified_multi_sequence_xml_with_points(
    sequence_one_points: str,
    sequence_two_points: str,
    period_end: str = "2026-05-13T01:15Z",
) -> bytes:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Publication_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3">
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>2</classificationSequence_AttributeInstanceComponent.position>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>{period_end}</end>
      </timeInterval>
      <resolution>PT15M</resolution>
{sequence_two_points}
    </Period>
  </TimeSeries>
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>1</classificationSequence_AttributeInstanceComponent.position>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>{period_end}</end>
      </timeInterval>
      <resolution>PT15M</resolution>
{sequence_one_points}
    </Period>
  </TimeSeries>
</Publication_MarketDocument>
""".encode()


def tomorrow_fallback_sequence_xml() -> bytes:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Publication_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3">
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>1</classificationSequence_AttributeInstanceComponent.position>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-12T22:00Z</start>
        <end>2026-05-13T00:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>2</position><price.amount>20</price.amount></Point>
    </Period>
  </TimeSeries>
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>2</classificationSequence_AttributeInstanceComponent.position>
    <curveType>A03</curveType>
    <Period>
      <timeInterval>
        <start>2026-05-13T22:00Z</start>
        <end>2026-05-14T00:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><price.amount>100</price.amount></Point>
      <Point><position>2</position><price.amount>200</price.amount></Point>
    </Period>
  </TimeSeries>
</Publication_MarketDocument>
""".encode()


def make_config(root: Path) -> Box:
    config = Box()
    config.paths = Box()
    config.paths.price_data_dir = root / "price_data"
    config.paths.price_data_dir.mkdir(parents=True)
    return config


def complete_hourly_price_data_for_day(day: date) -> Box:
    day_start = arrow.get(day.isoformat(), "YYYY-MM-DD", tzinfo=AREA.timezone)
    data = Box()
    data.source = "ENTSOE"
    data.area = AREA.key
    data.display_name = AREA.display_name
    data.entsoe_domain = AREA.entsoe_domain
    data.timezone = AREA.timezone
    data.currency = AREA.currency
    data.resolution = "PT60M"
    data.sequence_position = "1"
    data.fallback_sequence_positions = []
    data.fallback_price_count = 0
    data.prices = []
    for hour in range(24):
        point = Box()
        point.start_timestamp = day_start.shift(hours=+hour)
        point.end_timestamp = day_start.shift(hours=+(hour + 1))
        point.marketprice = prices.MarketPrice(Decimal(str(10 + hour)), AREA)
        point.sequence_position = "1"
        point.is_fallback = False
        data.prices.append(point)
    return data


class PriceHistoryTests(unittest.TestCase):
    def test_fresh_database_initialization_is_concurrency_safe(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = make_config(Path(temp_dir))

            def open_database():
                with price_database.connect(config) as connection:
                    return {
                        row[0]
                        for row in connection.execute(
                            "SELECT name FROM sqlite_master WHERE type = 'table'"
                        )
                    }

            with ThreadPoolExecutor(max_workers=8) as executor:
                table_sets = list(executor.map(lambda _: open_database(), range(16)))

            self.assertTrue(
                all(
                    {"price_points", "price_datasets"}.issubset(table_names)
                    for table_names in table_sets
                )
            )

    def test_price_storage_uses_only_sqlite(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                config = make_config(root)
                history_date = date(2026, 5, 13)
                data = complete_hourly_price_data_for_day(history_date)

                await prices.store_data(data, AREA.key, config)
                await prices.store_history_data(data, AREA.key, history_date, config)

                self.assertTrue(price_database.database_path(config).exists())
                self.assertEqual(list(root.rglob("*.pickle")), [])

        asyncio.run(run_test())

    def test_backfilled_archive_serves_existing_daily_history_endpoint(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
                history_date = date(2026, 5, 13)
                data = complete_hourly_price_data_for_day(history_date)
                price_database.store_dataset(config, AREA.key, "archive:test", data)

                stored = await prices.get_stored_history_data(AREA.key, history_date, config)

                self.assertIsNotNone(stored)
                self.assertTrue(prices.has_complete_local_day(stored, AREA, history_date))

        asyncio.run(run_test())

    def test_complete_stored_period_is_detected_from_price_points(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = make_config(Path(temp_dir))
            history_date = date(2026, 5, 13)
            data = complete_hourly_price_data_for_day(history_date)
            period_start = data.prices[0].start_timestamp.int_timestamp
            period_end = data.prices[-1].end_timestamp.int_timestamp
            price_database.store_dataset(config, AREA.key, "archive:test", data)

            self.assertTrue(
                price_database.period_is_complete(
                    config,
                    AREA.key,
                    period_start,
                    period_end,
                )
            )

    def test_missing_stored_interval_is_incomplete(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = make_config(Path(temp_dir))
            history_date = date(2026, 5, 13)
            data = complete_hourly_price_data_for_day(history_date)
            period_start = data.prices[0].start_timestamp.int_timestamp
            period_end = data.prices[-1].end_timestamp.int_timestamp
            data.prices.pop(12)
            price_database.store_dataset(config, AREA.key, "archive:incomplete", data)

            self.assertFalse(
                price_database.period_is_complete(
                    config,
                    AREA.key,
                    period_start,
                    period_end,
                )
            )

    def test_archive_backfills_multiple_areas_with_bounded_concurrency(self):
        async def run_test():
            active_count = 0
            peak_count = 0
            attempted_areas = []

            async def backfill_area(area_key, *_args, **_kwargs):
                nonlocal active_count, peak_count
                active_count += 1
                peak_count = max(peak_count, active_count)
                attempted_areas.append(area_key)
                await asyncio.sleep(0.01)
                active_count -= 1
                return 0

            with (
                patch.object(price_history_backfill, "backfill_area", side_effect=backfill_area),
                patch.object(price_history_backfill.logger, "info") as log_info,
            ):
                failures = await price_history_backfill.backfill_areas(
                    defaults.supported_market_area_keys,
                    2,
                    Box(),
                    prepare_current=False,
                    concurrency=3,
                )

            self.assertEqual(failures, 0)
            self.assertEqual(peak_count, 3)
            self.assertEqual(set(attempted_areas), set(defaults.supported_market_area_keys))
            self.assertIn("FR", attempted_areas)
            self.assertIn("PL", attempted_areas)
            log_info.assert_called_once_with(
                "Price archive backfill finished for all "
                f"{len(defaults.supported_market_area_keys)} checked areas."
            )

        asyncio.run(run_test())

    def test_incomplete_monthly_download_is_completed_with_daily_requests(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
                period_start = arrow.get("2026-05-13", "YYYY-MM-DD", tzinfo=AREA.timezone)
                period_end = period_start.shift(days=+2)
                first_day = complete_hourly_price_data_for_day(date(2026, 5, 13))
                second_day = complete_hourly_price_data_for_day(date(2026, 5, 14))

                with (
                    patch.object(
                        price_refresher,
                        "download_data",
                        new=AsyncMock(side_effect=[b"monthly", b"daily"]),
                    ) as download_data,
                    patch.object(
                        price_refresher,
                        "parse_downloaded_data",
                        side_effect=[first_day, second_day],
                    ),
                    patch.object(price_history_backfill.asyncio, "sleep", new=AsyncMock()),
                ):
                    failures = await price_history_backfill.backfill_area(
                        AREA.key,
                        period_start,
                        period_end,
                        config,
                        force=False,
                        prepare_current=False,
                    )

                self.assertEqual(failures, 0)
                self.assertEqual(download_data.await_count, 2)
                self.assertTrue(
                    price_database.period_is_complete(
                        config,
                        AREA.key,
                        period_start.int_timestamp,
                        period_end.int_timestamp,
                    )
                )

        asyncio.run(run_test())

    def test_existing_partial_month_downloads_only_missing_days(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
                period_start = arrow.get("2026-05-13", "YYYY-MM-DD", tzinfo=AREA.timezone)
                period_end = period_start.shift(days=+2)
                first_day = complete_hourly_price_data_for_day(date(2026, 5, 13))
                second_day = complete_hourly_price_data_for_day(date(2026, 5, 14))
                price_database.store_dataset(config, AREA.key, "archive:partial", first_day)

                with (
                    patch.object(
                        price_refresher,
                        "download_data",
                        new=AsyncMock(return_value=b"daily"),
                    ) as download_data,
                    patch.object(price_refresher, "parse_downloaded_data", return_value=second_day),
                    patch.object(price_history_backfill.asyncio, "sleep", new=AsyncMock()),
                ):
                    failures = await price_history_backfill.backfill_area(
                        AREA.key,
                        period_start,
                        period_end,
                        config,
                        force=False,
                        prepare_current=False,
                    )

                self.assertEqual(failures, 0)
                download_data.assert_awaited_once_with(
                    AREA,
                    config,
                    period_start.shift(days=+1),
                    period_end,
                )

        asyncio.run(run_test())

    def test_unavailable_entsoe_history_is_not_an_operational_failure(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
                period_start = arrow.get("2026-05-13", "YYYY-MM-DD", tzinfo=AREA.timezone)
                period_end = period_start.shift(days=+2)

                with (
                    patch.object(
                        price_refresher,
                        "download_data",
                        new=AsyncMock(return_value=None),
                    ) as download_data,
                    patch.object(price_history_backfill.asyncio, "sleep", new=AsyncMock()),
                    patch.object(price_history_backfill.logger, "warning") as log_warning,
                ):
                    failures = await price_history_backfill.backfill_area(
                        AREA.key,
                        period_start,
                        period_end,
                        config,
                        force=False,
                        prepare_current=False,
                    )

                self.assertEqual(failures, 0)
                self.assertEqual(download_data.await_count, 3)
                self.assertIn("Price history is unavailable", log_warning.call_args.args[0])

        asyncio.run(run_test())

    def test_usable_archive_gap_is_not_retried(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
                period_start = arrow.get("2026-02-01", "YYYY-MM-DD", tzinfo=AREA.timezone)
                period_end = period_start.shift(months=+1)
                data = complete_hourly_price_data_for_day(date(2026, 2, 1))
                for day in range(2, 29):
                    data.prices.extend(
                        complete_hourly_price_data_for_day(date(2026, 2, day)).prices
                    )
                data.prices = [
                    point
                    for point in data.prices
                    if point.start_timestamp.date() != date(2026, 2, 10)
                ]
                price_database.store_dataset(config, AREA.key, "archive:usable", data)

                with patch.object(
                    price_refresher,
                    "download_data",
                    new=AsyncMock(),
                ) as download_data:
                    failures = await price_history_backfill.backfill_area(
                        AREA.key,
                        period_start,
                        period_end,
                        config,
                        force=False,
                        prepare_current=False,
                    )

                self.assertEqual(failures, 0)
                download_data.assert_not_awaited()

        asyncio.run(run_test())

    def test_history_query_uses_market_area_day_with_dst(self):
        period_start, period_end = price_refresher.get_history_period(AREA, date(2026, 3, 29))
        query_params = price_refresher.get_entsoe_query_params(AREA, period_start, period_end)

        self.assertEqual(query_params["periodStart"], "202603282300")
        self.assertEqual(query_params["periodEnd"], "202603292200")

    def test_history_date_validation_allows_any_completed_day(self):
        with patch("awattprice.prices.arrow.now", return_value=arrow.get("2026-05-14T12:00:00+02:00")):
            self.assertTrue(prices.validate_history_date(AREA, date(2026, 5, 13)))
            self.assertTrue(prices.validate_history_date(AREA, date(2020, 1, 1)))
            self.assertFalse(prices.validate_history_date(AREA, date(2026, 5, 14)))
            self.assertFalse(prices.validate_history_date(AREA, date(2026, 5, 15)))

    def test_history_cache_hit_does_not_download(self):
        async def run_test():
            with tempfile.TemporaryDirectory() as temp_dir:
                config = make_config(Path(temp_dir))
                history_date = date(2026, 5, 13)
                cached_data = complete_hourly_price_data_for_day(history_date)
                await prices.store_history_data(cached_data, AREA.key, history_date, config)

                with patch("awattprice_refresher.prices.download_data", new=AsyncMock()) as download_data:
                    result = await price_refresher.refresh_history_prices(AREA.key, history_date, config)

                self.assertEqual(result.area, AREA.key)
                download_data.assert_not_awaited()

        asyncio.run(run_test())

    def test_history_response_preserves_fifteen_minute_intervals(self):
        data = price_refresher.parse_downloaded_data(AREA, price_xml("PT15M"))
        response = prices.parse_to_response_data(data)

        self.assertEqual(response.resolution, "PT15M")
        self.assertEqual(len(response.prices), 4)
        self.assertEqual(response.prices[1].start_timestamp - response.prices[0].start_timestamp, 15 * 60)

    def test_spring_dst_day_has_23_continuous_hourly_intervals(self):
        data = price_refresher.parse_downloaded_data(
            AREA,
            dst_day_price_xml("2025-03-29T23:00Z", "2025-03-30T22:00Z"),
        )
        period_start = arrow.get("2025-03-30", "YYYY-MM-DD", tzinfo=AREA.timezone)
        period_end = period_start.shift(days=+1)

        self.assertEqual(len(data.prices), 23)
        self.assertTrue(prices.has_complete_price_points(data, period_start, period_end))
        self.assertTrue(all(
            point.end_timestamp.int_timestamp - point.start_timestamp.int_timestamp == 60 * 60
            for point in data.prices
        ))

    def test_autumn_dst_day_has_25_continuous_hourly_intervals(self):
        data = price_refresher.parse_downloaded_data(
            AREA,
            dst_day_price_xml("2024-10-26T22:00Z", "2024-10-27T23:00Z"),
        )
        period_start = arrow.get("2024-10-27", "YYYY-MM-DD", tzinfo=AREA.timezone)
        period_end = period_start.shift(days=+1)

        self.assertEqual(len(data.prices), 25)
        self.assertTrue(prices.has_complete_price_points(data, period_start, period_end))
        self.assertTrue(all(
            point.end_timestamp.int_timestamp - point.start_timestamp.int_timestamp == 60 * 60
            for point in data.prices
        ))

    def test_unclassified_multiple_time_series_are_combined(self):
        data = price_refresher.parse_downloaded_data(AREA, unclassified_multi_series_xml())

        self.assertEqual(len(data.prices), 4)
        self.assertEqual(data.prices[0].marketprice.value, Decimal("10"))
        self.assertEqual(data.prices[-1].marketprice.value, Decimal("40"))

    def test_preferred_sequence_carries_forward_before_fallback_sequence(self):
        sequence_one_points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>2</position><price.amount>20</price.amount></Point>
      <Point><position>4</position><price.amount>40</price.amount></Point>
"""

        data = price_refresher.parse_downloaded_data(AREA, classified_multi_sequence_xml(sequence_one_points))
        response = prices.parse_to_response_data(data)

        self.assertEqual(data.sequence_position, "1")
        self.assertEqual(data.fallback_sequence_positions, [])
        self.assertEqual(data.fallback_price_count, 0)
        self.assertEqual(data.carried_forward_price_count, 1)
        self.assertEqual([point.marketprice.value for point in data.prices], [
            Decimal("10"),
            Decimal("20"),
            Decimal("20"),
            Decimal("40"),
        ])
        self.assertEqual([point.sequence_position for point in data.prices], ["1", "1", "1", "1"])
        self.assertEqual([point.is_fallback for point in data.prices], [False, False, False, False])
        self.assertEqual([point.is_carried_forward for point in data.prices], [False, False, True, False])
        self.assertEqual(response.fallback_price_count, 0)
        self.assertEqual(response.carried_forward_price_count, 1)
        self.assertTrue(response.prices[2].is_carried_forward)

    def test_missing_a03_gap_is_carried_forward(self):
        sequence_points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>4</position><price.amount>40</price.amount></Point>
"""

        data = price_refresher.parse_downloaded_data(
            AREA,
            classified_multi_sequence_xml_with_points(
                sequence_points,
                sequence_points,
                period_end="2026-05-13T01:00Z",
            ),
        )
        response = prices.parse_to_response_data(data)

        self.assertEqual([point.marketprice.value for point in data.prices], [
            Decimal("10"),
            Decimal("10"),
            Decimal("10"),
            Decimal("40"),
        ])
        self.assertEqual(data.carried_forward_price_count, 2)
        self.assertEqual([point.is_carried_forward for point in data.prices], [False, True, True, False])
        self.assertEqual(response.carried_forward_price_count, 2)

    def test_larger_a03_gap_is_carried_forward_without_limit(self):
        sequence_points = """
      <Point><position>1</position><price.amount>-0.01</price.amount></Point>
      <Point><position>11</position><price.amount>-0.02</price.amount></Point>
"""

        data = price_refresher.parse_downloaded_data(
            AREA,
            classified_multi_sequence_xml_with_points(
                sequence_points,
                sequence_points,
                period_end="2026-05-13T02:45Z",
            ),
        )

        self.assertEqual(len(data.prices), 11)
        self.assertEqual(data.carried_forward_price_count, 9)
        self.assertEqual([point.marketprice.value for point in data.prices[1:10]], [Decimal("-0.01")] * 9)
        self.assertEqual(data.prices[-1].marketprice.value, Decimal("-0.02"))

    def test_leading_preferred_sequence_gap_can_use_fallback_sequence(self):
        sequence_one_points = """
      <Point><position>2</position><price.amount>20</price.amount></Point>
      <Point><position>4</position><price.amount>40</price.amount></Point>
"""
        sequence_two_points = """
      <Point><position>1</position><price.amount>100</price.amount></Point>
      <Point><position>2</position><price.amount>200</price.amount></Point>
      <Point><position>3</position><price.amount>300</price.amount></Point>
      <Point><position>4</position><price.amount>400</price.amount></Point>
"""

        data = price_refresher.parse_downloaded_data(
            AREA,
            classified_multi_sequence_xml_with_points(
                sequence_one_points,
                sequence_two_points,
                period_end="2026-05-13T01:00Z",
            ),
        )

        self.assertEqual([point.marketprice.value for point in data.prices], [
            Decimal("100"),
            Decimal("20"),
            Decimal("20"),
            Decimal("40"),
        ])
        self.assertEqual(data.fallback_price_count, 1)
        self.assertEqual(data.carried_forward_price_count, 1)
        self.assertEqual([point.sequence_position for point in data.prices], ["2", "1", "1", "1"])
        self.assertEqual([point.is_fallback for point in data.prices], [True, False, False, False])

    def test_completed_preferred_sequence_replaces_fallback_prices(self):
        sequence_one_points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>2</position><price.amount>20</price.amount></Point>
      <Point><position>3</position><price.amount>30</price.amount></Point>
      <Point><position>4</position><price.amount>40</price.amount></Point>
"""

        data = price_refresher.parse_downloaded_data(AREA, classified_multi_sequence_xml(sequence_one_points))

        self.assertEqual([point.marketprice.value for point in data.prices], [
            Decimal("10"),
            Decimal("20"),
            Decimal("30"),
            Decimal("40"),
        ])
        self.assertEqual(data.fallback_price_count, 0)
        self.assertTrue(all(point.sequence_position == "1" for point in data.prices))
        self.assertFalse(any(point.is_fallback for point in data.prices))

    def test_tomorrow_fallback_only_sequence_is_blocked_before_cutoff(self):
        data = price_refresher.parse_downloaded_data(
            AREA,
            tomorrow_fallback_sequence_xml(),
            now=arrow.get("2026-05-13T14:00:00+02:00"),
        )

        self.assertEqual(data.sequence_position, "1")
        self.assertEqual(data.fallback_price_count, 0)
        self.assertEqual(len(data.prices), 2)
        self.assertEqual(data.prices[-1].end_timestamp, arrow.get("2026-05-13T02:00:00+02:00"))

    def test_tomorrow_fallback_only_sequence_is_allowed_after_cutoff(self):
        data = price_refresher.parse_downloaded_data(
            AREA,
            tomorrow_fallback_sequence_xml(),
            now=arrow.get("2026-05-13T17:00:00+02:00"),
        )

        self.assertEqual(data.fallback_sequence_positions, ["2"])
        self.assertEqual(data.fallback_price_count, 2)
        self.assertEqual(len(data.prices), 4)
        self.assertEqual([point.is_fallback for point in data.prices], [False, False, True, True])

    def test_blocked_fallback_cache_can_be_replaced_by_primary_only_data(self):
        fallback_data = price_refresher.parse_downloaded_data(
            AREA,
            tomorrow_fallback_sequence_xml(),
            now=arrow.get("2026-05-13T17:00:00+02:00"),
        )
        primary_only_data = price_refresher.parse_downloaded_data(
            AREA,
            tomorrow_fallback_sequence_xml(),
            now=arrow.get("2026-05-13T14:00:00+02:00"),
        )

        with patch("awattprice_refresher.prices.arrow.now", return_value=arrow.get("2026-05-13T14:00:00+02:00")):
            self.assertTrue(price_refresher.check_data_new(fallback_data, primary_only_data, AREA))


class PriceHistoryAPITests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(api.app)

    def test_uncached_old_history_is_downloaded_without_storing(self):
        price_data = price_refresher.parse_downloaded_data(AREA, price_xml())

        with (
            patch.object(api.prices, "get_stored_history_data", new=AsyncMock(return_value=None)),
            patch.object(api, "is_retained_history_date", return_value=False),
            patch.object(
                api.price_refresher,
                "download_history_prices",
                new=AsyncMock(return_value=price_data),
            ) as download_history,
            patch.object(api.prices, "store_history_data", new=AsyncMock()) as store_history,
        ):
            response = self.client.get("/prices/DE-LU/history/2026-05-01")

        self.assertEqual(response.status_code, 200)
        download_history.assert_awaited_once()
        store_history.assert_not_awaited()

    def test_retained_missing_history_is_refreshed_and_stored_by_api(self):
        price_data = price_refresher.parse_downloaded_data(AREA, price_xml())

        with (
            patch.object(api.prices, "get_stored_history_data", new=AsyncMock(return_value=None)),
            patch.object(api, "is_retained_history_date", return_value=True),
            patch.object(
                api.price_refresher,
                "refresh_history_prices",
                new=AsyncMock(return_value=price_data),
            ) as refresh_history,
            patch.object(api.price_refresher, "download_history_prices", new=AsyncMock()) as download_history,
        ):
            response = self.client.get("/prices/DE-LU/history/2026-05-24")

        self.assertEqual(response.status_code, 200)
        refresh_history.assert_awaited_once_with("DE-LU", date(2026, 5, 24), api.config)
        download_history.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
