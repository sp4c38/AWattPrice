"""Supported ENTSO-E market areas."""
from dataclasses import dataclass
from decimal import Decimal
from typing import Optional


@dataclass(frozen=True)
class MarketArea:
    """Describe a supported market area."""

    key: str
    entsoe_domain: str
    display_name: str
    country_code: str
    timezone: str
    tax_multiplier: Optional[Decimal]
    currency: str = "EUR"
    price_measurement_unit: str = "MWH"
    subunits_per_currency_unit: int = 100
    decimal_separator: str = ","
    preferred_price_sequence: Optional[int] = 1


def create_market_area(
    key: str,
    entsoe_domain: str,
    display_name: str,
    country_code: str,
    timezone: str,
    tax_multiplier: Optional[str] = None,
    preferred_price_sequence: Optional[int] = 1,
) -> MarketArea:
    """Build a market area with sane defaults."""
    decimal_tax_multiplier = Decimal(tax_multiplier) if tax_multiplier is not None else None
    return MarketArea(
        key=key,
        entsoe_domain=entsoe_domain,
        display_name=display_name,
        country_code=country_code,
        timezone=timezone,
        tax_multiplier=decimal_tax_multiplier,
        preferred_price_sequence=preferred_price_sequence,
    )


PRICE_ZONE_CANDIDATES = [
        create_market_area("AL", "10YAL-KESH-----5", "Albania", "AL", "Europe/Tirane"),
        create_market_area("AM", "10Y1001A1001B004", "Armenia", "AM", "Asia/Yerevan"),
        create_market_area("AT", "10YAT-APG------L", "Austria", "AT", "Europe/Vienna", tax_multiplier="1.20"),
        create_market_area("AZ", "10Y1001A1001B05V", "Azerbaijan", "AZ", "Asia/Baku"),
        create_market_area("BA", "10YBA-JPCC-----D", "Bosnia and Herzegovina", "BA", "Europe/Sarajevo"),
        create_market_area("BE", "10YBE----------2", "Belgium", "BE", "Europe/Brussels"),
        create_market_area("BG", "10YCA-BULGARIA-R", "Bulgaria", "BG", "Europe/Sofia"),
        create_market_area("CH", "10YCH-SWISSGRIDZ", "Switzerland", "CH", "Europe/Zurich"),
        create_market_area("CY", "10YCY-1001A0003J", "Cyprus", "CY", "Asia/Nicosia"),
        create_market_area("CZ", "10YCZ-CEPS-----N", "Czech Republic", "CZ", "Europe/Prague"),
        create_market_area("DE-LU", "10Y1001A1001A82H", "Germany / Luxembourg", "DE", "Europe/Berlin", tax_multiplier="1.19"),
        create_market_area("DK1", "10YDK-1--------W", "Denmark West", "DK", "Europe/Copenhagen"),
        create_market_area("DK2", "10YDK-2--------M", "Denmark East", "DK", "Europe/Copenhagen"),
        create_market_area("EE", "10Y1001A1001A39I", "Estonia", "EE", "Europe/Tallinn"),
        create_market_area("ES", "10YES-REE------0", "Spain", "ES", "Europe/Madrid"),
        create_market_area("FI", "10YFI-1--------U", "Finland", "FI", "Europe/Helsinki"),
        create_market_area("FR", "10YFR-RTE------C", "France", "FR", "Europe/Paris"),
        create_market_area("GB", "10YGB----------A", "United Kingdom", "GB", "Europe/London"),
        create_market_area("GE", "10Y1001A1001B012", "Georgia", "GE", "Asia/Tbilisi"),
        create_market_area("GR", "10YGR-HTSO-----Y", "Greece", "GR", "Europe/Athens"),
        create_market_area("HR", "10YHR-HEP------M", "Croatia", "HR", "Europe/Zagreb"),
        create_market_area("HU", "10YHU-MAVIR----U", "Hungary", "HU", "Europe/Budapest"),
        create_market_area("IE(SEM)", "10Y1001A1001A59C", "Ireland (SEM)", "IE", "Europe/Dublin"),
        create_market_area("IT-Brindisi", "10Y1001A1001A699", "Italy Brindisi", "IT", "Europe/Rome"),
        create_market_area("IT-Calabria", "10Y1001C--00096J", "Italy Calabria", "IT", "Europe/Rome"),
        create_market_area("IT-Centre-North", "10Y1001A1001A70O", "Italy Centre-North", "IT", "Europe/Rome"),
        create_market_area("IT-Centre-South", "10Y1001A1001A71M", "Italy Centre-South", "IT", "Europe/Rome"),
        create_market_area("IT-Foggia", "10Y1001A1001A72K", "Italy Foggia", "IT", "Europe/Rome"),
        create_market_area("IT-North", "10Y1001A1001A73I", "Italy North", "IT", "Europe/Rome"),
        create_market_area("IT-Priolo", "10Y1001A1001A76C", "Italy Priolo", "IT", "Europe/Rome"),
        create_market_area("IT-Rossano", "10Y1001A1001A77A", "Italy Rossano", "IT", "Europe/Rome"),
        create_market_area("IT-Sardinia", "10Y1001A1001A74G", "Italy Sardinia", "IT", "Europe/Rome"),
        create_market_area("IT-Sicily", "10Y1001A1001A75E", "Italy Sicily", "IT", "Europe/Rome"),
        create_market_area("IT-South", "10Y1001A1001A788", "Italy South", "IT", "Europe/Rome"),
        create_market_area("LT", "10YLT-1001A0008Q", "Lithuania", "LT", "Europe/Vilnius"),
        create_market_area("LV", "10YLV-1001A00074", "Latvia", "LV", "Europe/Riga"),
        create_market_area("MD", "10Y1001A1001A990", "Moldova", "MD", "Europe/Chisinau"),
        create_market_area("ME", "10YCS-CG-TSO---S", "Montenegro", "ME", "Europe/Podgorica"),
        create_market_area("MK", "10YMK-MEPSO----8", "North Macedonia", "MK", "Europe/Skopje"),
        create_market_area("MT", "10Y1001A1001A93C", "Malta", "MT", "Europe/Malta"),
        create_market_area("NL", "10YNL----------L", "Netherlands", "NL", "Europe/Amsterdam"),
        create_market_area("NO1", "10YNO-1--------2", "Norway NO1", "NO", "Europe/Oslo"),
        create_market_area("NO2", "10YNO-2--------T", "Norway NO2", "NO", "Europe/Oslo"),
        create_market_area("NO3", "10YNO-3--------J", "Norway NO3", "NO", "Europe/Oslo"),
        create_market_area("NO4", "10YNO-4--------9", "Norway NO4", "NO", "Europe/Oslo"),
        create_market_area("NO5", "10Y1001A1001A48H", "Norway NO5", "NO", "Europe/Oslo"),
        create_market_area("PL", "10YPL-AREA-----S", "Poland", "PL", "Europe/Warsaw"),
        create_market_area("PT", "10YPT-REN------W", "Portugal", "PT", "Europe/Lisbon"),
        create_market_area("RO", "10YRO-TEL------P", "Romania", "RO", "Europe/Bucharest"),
        create_market_area("RS", "10YCS-SERBIATSOV", "Serbia", "RS", "Europe/Belgrade"),
        create_market_area("SE1", "10Y1001A1001A44P", "Sweden SE1", "SE", "Europe/Stockholm"),
        create_market_area("SE2", "10Y1001A1001A45N", "Sweden SE2", "SE", "Europe/Stockholm"),
        create_market_area("SE3", "10Y1001A1001A46L", "Sweden SE3", "SE", "Europe/Stockholm"),
        create_market_area("SE4", "10Y1001A1001A47J", "Sweden SE4", "SE", "Europe/Stockholm"),
        create_market_area("SI", "10YSI-ELES-----O", "Slovenia", "SI", "Europe/Ljubljana"),
        create_market_area("SK", "10YSK-SEPS-----K", "Slovakia", "SK", "Europe/Bratislava"),
        create_market_area("TR", "10YTR-TEIAS----W", "Turkey", "TR", "Europe/Istanbul"),
        create_market_area("UA", "10Y1001C--00003F", "Ukraine", "UA", "Europe/Kyiv"),
        create_market_area("UA-BEI", "10YUA-WEPS-----0", "Ukraine BEI", "UA", "Europe/Kyiv"),
        create_market_area("UA-DobTPP", "10Y1001A1001A869", "Ukraine Dobrotvir TPP", "UA", "Europe/Kyiv"),
        create_market_area("UA-IPS", "10Y1001C--000182", "Ukraine IPS", "UA", "Europe/Kyiv"),
        create_market_area("XK", "10Y1001C--00100H", "Kosovo", "XK", "Europe/Belgrade"),
]

SUPPORTED_PRICE_ZONE_KEYS = [
    "AL",
    "AT",
    "BE",
    "BG",
    "CH",
    "CZ",
    "DE-LU",
    "DK1",
    "DK2",
    "EE",
    "ES",
    "FI",
    "FR",
    "GR",
    "HR",
    "HU",
    "IE(SEM)",
    "IT-Calabria",
    "IT-Centre-North",
    "IT-Centre-South",
    "IT-North",
    "IT-Sardinia",
    "IT-Sicily",
    "IT-South",
    "LT",
    "LV",
    "ME",
    "MK",
    "NL",
    "NO1",
    "NO2",
    "NO3",
    "NO4",
    "NO5",
    "PL",
    "PT",
    "RO",
    "RS",
    "SE1",
    "SE2",
    "SE3",
    "SE4",
    "SI",
    "SK",
    "UA-IPS",
]

SUPPORTED_MARKET_AREAS = {
    area.key: area
    for area in PRICE_ZONE_CANDIDATES
    if area.key in SUPPORTED_PRICE_ZONE_KEYS
}

DEFAULT_MARKET_AREA_KEY = "DE-LU"


def normalize_market_area_key(value: str) -> str:
    """Normalize external market-area keys."""
    normalized_value = value.strip().replace("_", "-")
    upper_normalized_value = normalized_value.upper()
    for area_key in SUPPORTED_MARKET_AREAS:
        if area_key.upper() == upper_normalized_value:
            return area_key

    return upper_normalized_value


def get_market_area(area_key: str) -> MarketArea:
    """Get a supported market area by key."""
    normalized_key = normalize_market_area_key(area_key)
    return SUPPORTED_MARKET_AREAS[normalized_key]


def list_market_areas() -> list[MarketArea]:
    """Return supported market areas in declaration order."""
    return list(SUPPORTED_MARKET_AREAS.values())


def list_price_zone_candidates() -> list[MarketArea]:
    """Return all known ENTSO-E price-zone candidates."""
    return list(PRICE_ZONE_CANDIDATES)
