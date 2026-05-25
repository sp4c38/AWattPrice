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


def test_config(root: Path) -> Box:
    config = Box()
    config.paths = Box()
    config.paths.price_data_dir = root / "price_data"
    config.paths.price_data_dir.mkdir(parents=True)
    return config


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
                cached_data = Box()
                cached_data.source = "ENTSOE"
                cached_data.area = AREA.key
                cached_data.display_name = AREA.display_name
                cached_data.entsoe_domain = AREA.entsoe_domain
                cached_data.timezone = AREA.timezone
                cached_data.currency = AREA.currency
                cached_data.resolution = "PT60M"
                cached_data.sequence_position = "1"

                point = Box()
                point.start_timestamp = arrow.get("2026-05-13T00:00:00+02:00")
                point.end_timestamp = arrow.get("2026-05-13T01:00:00+02:00")
                point.marketprice = prices.MarketPrice(Decimal("10"), AREA)
                cached_data.prices = [point]

                history_date = date(2026, 5, 13)
                await prices.store_history_data(cached_data, AREA.key, history_date, config)

                with patch("awattprice_refresher.prices.download_data", new=AsyncMock()) as download_data:
                    result = await price_refresher.refresh_history_prices(AREA.key, history_date, config)

                self.assertEqual(result.area, AREA.key)
                download_data.assert_not_awaited()

        asyncio.run(run_test())

    def test_history_response_preserves_fifteen_minute_intervals(self):
        data = prices.parse_downloaded_data(AREA, price_xml("PT15M"))
        response = prices.parse_to_response_data(data)

        self.assertEqual(response.resolution, "PT15M")
        self.assertEqual(len(response.prices), 4)
        self.assertEqual(response.prices[1].start_timestamp - response.prices[0].start_timestamp, 15 * 60)

    def test_unclassified_multiple_time_series_are_combined(self):
        data = prices.parse_downloaded_data(AREA, unclassified_multi_series_xml())

        self.assertEqual(len(data.prices), 4)
        self.assertEqual(data.prices[0].marketprice.value, Decimal("10"))
        self.assertEqual(data.prices[-1].marketprice.value, Decimal("40"))


if __name__ == "__main__":
    unittest.main()
