import unittest

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
