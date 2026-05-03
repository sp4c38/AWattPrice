from __future__ import annotations

import sys

from datetime import datetime
from datetime import timedelta
from pathlib import Path
from urllib.error import HTTPError
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import urlopen
from xml.etree import ElementTree as ET
from zoneinfo import ZoneInfo


TOKEN_PATH = Path("/Users/lbecker/awattprice/entsoe-token.txt")
API_URL = "https://web-api.tp.entsoe.eu/api"
GERMANY_DOMAIN_CANDIDATES = [
    ("BZN|DE-LU", "10Y1001A1001A82H"),
    ("Germany (DE)", "10Y1001A1001A83F"),
]
BERLIN = ZoneInfo("Europe/Berlin")
NS = {
    "publication": "{*}",
    "ack": "{*}",
}
RESOLUTION_TO_DELTA = {
    "PT15M": timedelta(minutes=15),
    "PT30M": timedelta(minutes=30),
    "PT60M": timedelta(hours=1),
}


def to_entsoe_timestamp(value: datetime) -> str:
    return value.astimezone(ZoneInfo("UTC")).strftime("%Y%m%d%H%M")


def build_url(domain: str) -> str:
    now = datetime.now(BERLIN)
    start_local = now.replace(hour=0, minute=0, second=0, microsecond=0)
    end_local = start_local + timedelta(days=2)

    token = TOKEN_PATH.read_text().strip()
    params = {
        "securityToken": token,
        "documentType": "A44",
        "in_Domain": domain,
        "out_Domain": domain,
        "periodStart": to_entsoe_timestamp(start_local),
        "periodEnd": to_entsoe_timestamp(end_local),
    }
    return f"{API_URL}?{urlencode(params)}"


def parse_prices(xml_bytes: bytes) -> list[dict[str, object]]:
    root = ET.fromstring(xml_bytes)

    if root.tag.endswith("Acknowledgement_MarketDocument"):
        reason = root.findtext(".//{*}text") or "Unknown ENTSO-E error"
        raise RuntimeError(reason)

    series_list: list[dict[str, object]] = []
    for time_series in root.findall(".//{*}TimeSeries"):
        period = time_series.find("{*}Period")
        if period is None:
            continue

        start_text = period.findtext("{*}timeInterval/{*}start")
        resolution_text = period.findtext("{*}resolution")
        step = RESOLUTION_TO_DELTA.get(resolution_text or "")
        if not start_text or step is None:
            continue

        start = datetime.fromisoformat(start_text.replace("Z", "+00:00"))
        prices: list[tuple[str, str]] = []
        for point in period.findall("{*}Point"):
            position_text = point.findtext("{*}position")
            price_text = point.findtext("{*}price.amount")
            if not position_text or not price_text:
                continue

            position = int(position_text)
            point_start = start + step * (position - 1)
            point_start_local = point_start.astimezone(BERLIN)
            prices.append((point_start_local.isoformat(), price_text))

        if prices:
            series_list.append(
                {
                    "classification_position": time_series.findtext(
                        "{*}classificationSequence_AttributeInstanceComponent.position"
                    ),
                    "resolution": resolution_text,
                    "prices": prices,
                }
            )

    return series_list


def fetch_prices() -> tuple[str, list[dict[str, object]]]:
    errors: list[str] = []

    for label, domain in GERMANY_DOMAIN_CANDIDATES:
        url = build_url(domain)
        try:
            with urlopen(url) as response:
                xml_bytes = response.read()
            prices = parse_prices(xml_bytes)
            if prices:
                return label, prices
            errors.append(f"{label}: no prices in response")
        except HTTPError as exc:
            errors.append(f"{label}: HTTP {exc.code}")
        except URLError as exc:
            errors.append(f"{label}: {exc.reason}")
        except Exception as exc:
            errors.append(f"{label}: {exc}")

    raise RuntimeError(" / ".join(errors))


def main() -> int:
    if not TOKEN_PATH.is_file():
        print(f"Missing token file: {TOKEN_PATH}", file=sys.stderr)
        return 1

    try:
        label, series_list = fetch_prices()
    except Exception as exc:
        print(f"ENTSO-E request failed: {exc}", file=sys.stderr)
        return 1

    print(f"Downloaded {len(series_list)} time series for {label}.")
    for index, series in enumerate(series_list, start=1):
        classification_position = series["classification_position"]
        resolution = series["resolution"]
        prices = series["prices"]
        print()
        print(
            f"Time series {index}: classification position {classification_position}, "
            f"resolution {resolution}, {len(prices)} points"
        )
        for timestamp, price in prices:
            print(f"{timestamp}  {price} EUR/MWh")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
