import asyncio
import tempfile
import unittest

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
from awattprice import prices
from awattprice_refresher import prices as price_refresher


AREA = defaults.get_market_area("DE-LU")


def price_xml(resolution: str = "PT60M") -> bytes:
    if resolution == "PT15M":
        points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>2</position><price.amount>20</price.amount></Point>
      <Point><position>3</position><price.amount>30</price.amount></Point>
      <Point><position>4</position><price.amount>40</price.amount></Point>
"""
    else:
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
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>2026-05-13T02:00Z</end>
      </timeInterval>
      <resolution>{resolution}</resolution>
{points}
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


def classified_multi_sequence_xml_with_points(sequence_one_points: str, sequence_two_points: str) -> bytes:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Publication_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3">
  <TimeSeries>
    <in_Domain.mRID>{AREA.entsoe_domain}</in_Domain.mRID>
    <out_Domain.mRID>{AREA.entsoe_domain}</out_Domain.mRID>
    <currency_Unit.name>EUR</currency_Unit.name>
    <classificationSequence_AttributeInstanceComponent.position>2</classificationSequence_AttributeInstanceComponent.position>
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>2026-05-13T01:15Z</end>
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
    <Period>
      <timeInterval>
        <start>2026-05-13T00:00Z</start>
        <end>2026-05-13T01:15Z</end>
      </timeInterval>
      <resolution>PT15M</resolution>
{sequence_one_points}
    </Period>
  </TimeSeries>
</Publication_MarketDocument>
""".encode()


def test_config(root: Path) -> Box:
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
                config = test_config(Path(temp_dir))
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

    def test_unclassified_multiple_time_series_are_combined(self):
        data = price_refresher.parse_downloaded_data(AREA, unclassified_multi_series_xml())

        self.assertEqual(len(data.prices), 4)
        self.assertEqual(data.prices[0].marketprice.value, Decimal("10"))
        self.assertEqual(data.prices[-1].marketprice.value, Decimal("40"))

    def test_preferred_sequence_is_filled_from_fallback_sequence(self):
        sequence_one_points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>2</position><price.amount>20</price.amount></Point>
      <Point><position>4</position><price.amount>40</price.amount></Point>
"""

        data = price_refresher.parse_downloaded_data(AREA, classified_multi_sequence_xml(sequence_one_points))
        response = prices.parse_to_response_data(data)

        self.assertEqual(data.sequence_position, "1")
        self.assertEqual(data.fallback_sequence_positions, ["2"])
        self.assertEqual(data.fallback_price_count, 1)
        self.assertEqual([point.marketprice.value for point in data.prices], [
            Decimal("10"),
            Decimal("20"),
            Decimal("300"),
            Decimal("40"),
        ])
        self.assertEqual([point.sequence_position for point in data.prices], ["1", "1", "2", "1"])
        self.assertEqual([point.is_fallback for point in data.prices], [False, False, True, False])
        self.assertEqual(response.fallback_price_count, 1)
        self.assertTrue(response.prices[2].is_fallback)

    def test_tiny_missing_gap_is_interpolated_when_no_sequence_has_price(self):
        sequence_points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>4</position><price.amount>40</price.amount></Point>
"""

        data = price_refresher.parse_downloaded_data(
            AREA,
            classified_multi_sequence_xml_with_points(sequence_points, sequence_points),
        )
        response = prices.parse_to_response_data(data)

        self.assertEqual([point.marketprice.value for point in data.prices], [
            Decimal("10"),
            Decimal("20"),
            Decimal("30"),
            Decimal("40"),
        ])
        self.assertEqual(data.interpolated_price_count, 2)
        self.assertEqual([point.is_interpolated for point in data.prices], [False, True, True, False])
        self.assertEqual(response.interpolated_price_count, 2)
        self.assertTrue(response.prices[1].is_interpolated)

    def test_wider_missing_gap_is_not_interpolated(self):
        sequence_points = """
      <Point><position>1</position><price.amount>10</price.amount></Point>
      <Point><position>5</position><price.amount>50</price.amount></Point>
"""

        data = price_refresher.parse_downloaded_data(
            AREA,
            classified_multi_sequence_xml_with_points(sequence_points, sequence_points),
        )

        self.assertEqual([point.marketprice.value for point in data.prices], [
            Decimal("10"),
            Decimal("50"),
        ])
        self.assertEqual(data.interpolated_price_count, 0)
        self.assertFalse(any(point.is_interpolated for point in data.prices))

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

    def test_retained_missing_history_is_not_downloaded_by_api(self):
        with (
            patch.object(api.prices, "get_stored_history_data", new=AsyncMock(return_value=None)),
            patch.object(api, "is_retained_history_date", return_value=True),
            patch.object(api.price_refresher, "download_history_prices", new=AsyncMock()) as download_history,
        ):
            response = self.client.get("/prices/DE-LU/history/2026-05-24")

        self.assertEqual(response.status_code, 503)
        download_history.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
