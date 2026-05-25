import unittest

from decimal import Decimal
from unittest.mock import AsyncMock
from unittest.mock import patch

from box import Box
from fastapi.testclient import TestClient

from awattprice import api
from awattprice import generation_mix
from awattprice.market_areas import create_market_area


AREA = create_market_area("DE-LU", "10Y1001A1001A82H", "Germany / Luxembourg", "DE", "Europe/Berlin")


def generation_xml() -> bytes:
    return b"""<?xml version="1.0" encoding="UTF-8"?>
<GL_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-6:generationloaddocument:3:0">
  <TimeSeries>
    <MktPSRType>
      <psrType>B16</psrType>
      <powerSystemResources><name>Solar</name></powerSystemResources>
    </MktPSRType>
    <Period>
      <timeInterval>
        <start>2026-05-14T10:00Z</start>
        <end>2026-05-14T12:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><quantity>100</quantity></Point>
      <Point><position>2</position><quantity>120</quantity></Point>
    </Period>
  </TimeSeries>
  <TimeSeries>
    <MktPSRType>
      <psrType>B19</psrType>
      <powerSystemResources><name>Wind Onshore</name></powerSystemResources>
    </MktPSRType>
    <Period>
      <timeInterval>
        <start>2026-05-14T10:00Z</start>
        <end>2026-05-14T12:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><quantity>200</quantity></Point>
      <Point><position>2</position><quantity>180</quantity></Point>
    </Period>
  </TimeSeries>
  <TimeSeries>
    <MktPSRType>
      <psrType>B04</psrType>
      <powerSystemResources><name>Fossil Gas</name></powerSystemResources>
    </MktPSRType>
    <Period>
      <timeInterval>
        <start>2026-05-14T10:00Z</start>
        <end>2026-05-14T12:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><quantity>300</quantity></Point>
      <Point><position>2</position><quantity>300</quantity></Point>
    </Period>
  </TimeSeries>
</GL_MarketDocument>
"""


def staggered_generation_xml() -> bytes:
    return b"""<?xml version="1.0" encoding="UTF-8"?>
<GL_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-6:generationloaddocument:3:0">
  <TimeSeries>
    <MktPSRType><psrType>B16</psrType></MktPSRType>
    <Period>
      <timeInterval>
        <start>2026-05-14T10:00Z</start>
        <end>2026-05-14T12:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><quantity>100</quantity></Point>
      <Point><position>2</position><quantity>120</quantity></Point>
    </Period>
  </TimeSeries>
  <TimeSeries>
    <MktPSRType><psrType>B19</psrType></MktPSRType>
    <Period>
      <timeInterval>
        <start>2026-05-14T10:00Z</start>
        <end>2026-05-14T13:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><quantity>200</quantity></Point>
      <Point><position>2</position><quantity>180</quantity></Point>
      <Point><position>3</position><quantity>999</quantity></Point>
    </Period>
  </TimeSeries>
  <TimeSeries>
    <MktPSRType><psrType>B04</psrType></MktPSRType>
    <Period>
      <timeInterval>
        <start>2026-05-14T10:00Z</start>
        <end>2026-05-14T12:00Z</end>
      </timeInterval>
      <resolution>PT60M</resolution>
      <Point><position>1</position><quantity>300</quantity></Point>
      <Point><position>2</position><quantity>300</quantity></Point>
    </Period>
  </TimeSeries>
</GL_MarketDocument>
"""


class GenerationMixParsingTests(unittest.TestCase):
    def test_parse_groups_latest_interval_by_generation_category(self):
        data = generation_mix.parse_downloaded_data(AREA, generation_xml())
        response = generation_mix.parse_to_response_data(data)

        categories = {category.category: category for category in response.categories}

        self.assertEqual(response.resolution, "PT60M")
        self.assertEqual(response.total_generation_mw, 600.0)
        self.assertEqual(response.renewable_generation_mw, 300.0)
        self.assertEqual(response.renewable_share, 50.0)
        self.assertEqual(categories["solar"].generation_mw, 120.0)
        self.assertEqual(categories["wind"].generation_mw, 180.0)
        self.assertEqual(categories["fossil"].generation_mw, 300.0)

    def test_unknown_production_type_becomes_other(self):
        self.assertEqual(generation_mix.production_category("B99"), "other")
        self.assertEqual(generation_mix.production_category(None), "other")

    def test_latest_interval_uses_representative_mix_when_types_lag(self):
        data = generation_mix.parse_downloaded_data(AREA, staggered_generation_xml())
        response = generation_mix.parse_to_response_data(data)

        categories = {category.category: category for category in response.categories}

        self.assertEqual(response.total_generation_mw, 600.0)
        self.assertEqual(response.renewable_share, 50.0)
        self.assertEqual(categories["wind"].generation_mw, 180.0)

    def test_history_response_groups_representative_intervals(self):
        data = generation_mix.parse_downloaded_data(AREA, staggered_generation_xml())
        response = generation_mix.parse_to_history_response_data(data)

        categories = {category.category: category for category in response.categories}

        self.assertEqual(len(response.intervals), 2)
        self.assertEqual(response.total_generation_mw, 1200.0)
        self.assertEqual(response.renewable_generation_mw, 600.0)
        self.assertEqual(response.renewable_share, 50.0)
        self.assertEqual(categories["solar"].generation_mw, 220.0)
        self.assertEqual(categories["wind"].generation_mw, 380.0)
        self.assertEqual(categories["fossil"].generation_mw, 600.0)

    def test_history_keeps_near_complete_intervals(self):
        data = generation_mix.parse_downloaded_data(AREA, generation_xml())
        latest_point = data.generation_points[-1]

        extra_point = Box()
        extra_point.start_timestamp = latest_point.start_timestamp
        extra_point.end_timestamp = latest_point.end_timestamp
        extra_point.raw_production_type = "B17"
        extra_point.raw_production_name = "Other"
        extra_point.category = "other"
        extra_point.quantity_mw = Decimal("10")
        extra_point.is_renewable = False
        data.generation_points.append(extra_point)

        response = generation_mix.parse_to_history_response_data(data)

        self.assertEqual(len(response.intervals), 2)
        self.assertEqual(response.total_generation_mw, 1210.0)

    def test_history_respects_requested_hour_window(self):
        data = generation_mix.parse_downloaded_data(AREA, generation_xml())
        response = generation_mix.parse_to_history_response_data(data, hours=1)

        self.assertEqual(len(response.intervals), 1)
        self.assertEqual(response.total_generation_mw, 600.0)


class GenerationMixAPITests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(api.app)

    def test_history_endpoint_requires_hours_param(self):
        response = self.client.get("/generation-mix/DE-LU/history")
        self.assertEqual(response.status_code, 422)

    def test_history_endpoint_accepts_168_hours(self):
        with (
            patch.object(api.generation_mix, "get_stored_data", new=AsyncMock(return_value=Box())),
            patch.object(
                api.generation_mix,
                "parse_to_history_response_data",
                return_value={"intervals": [], "hours": 168},
            ) as parse,
        ):
            response = self.client.get("/generation-mix/DE-LU/history?hours=168")

        self.assertEqual(response.status_code, 200)
        parse.assert_called_once()
        self.assertEqual(parse.call_args.kwargs["hours"], 168)

    def test_history_endpoint_rejects_non_168_hours(self):
        for hours in [24, 48, 72, 167, 169]:
            with self.subTest(hours=hours):
                response = self.client.get(f"/generation-mix/DE-LU/history?hours={hours}")
                self.assertEqual(response.status_code, 422)
