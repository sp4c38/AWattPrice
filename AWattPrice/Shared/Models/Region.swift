//
//  Region.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Foundation

struct MarketArea: Codable, Hashable, Identifiable {
    let key: String
    let displayName: String
    let countryCode: String
    let timezone: String
    let currency: String
    let taxMultiplier: Double?

    enum CodingKeys: String, CodingKey {
        case key
        case displayName = "display_name"
        case countryCode = "country_code"
        case timezone
        case currency
        case taxMultiplier = "tax_multiplier"
    }

    var id: String { key }

    var localizedDisplayName: String {
        switch key {
        case "DE-LU":
            return NSLocalizedString("Germany / Luxembourg", comment: "")
        case "AT":
            return NSLocalizedString("Austria", comment: "")
        default:
            return displayName
        }
    }

    var settingsLabel: String {
        localizedDisplayName
    }

    var settingsFlag: String {
        switch countryCode {
        case "DE":
            return "DE"
        case "AT":
            return "AT"
        default:
            return countryCode
        }
    }

    private static func fallbackArea(
        _ key: String,
        _ displayName: String,
        _ countryCode: String,
        _ timezone: String,
        taxMultiplier: Double? = nil
    ) -> MarketArea {
        MarketArea(
            key: key,
            displayName: displayName,
            countryCode: countryCode,
            timezone: timezone,
            currency: "EUR",
            taxMultiplier: taxMultiplier
        )
    }

    static let germanyLuxembourg = MarketArea(
        key: "DE-LU",
        displayName: "Germany / Luxembourg",
        countryCode: "DE",
        timezone: "Europe/Berlin",
        currency: "EUR",
        taxMultiplier: 1.19
    )

    static let austria = MarketArea(
        key: "AT",
        displayName: "Austria",
        countryCode: "AT",
        timezone: "Europe/Vienna",
        currency: "EUR",
        taxMultiplier: 1.20
    )

    static let defaultAreaKey = germanyLuxembourg.key

    static let fallbackAreas: [MarketArea] = [
        fallbackArea("AL", "Albania", "AL", "Europe/Tirane"),
        fallbackArea("AM", "Armenia", "AM", "Asia/Yerevan"),
        austria,
        fallbackArea("AZ", "Azerbaijan", "AZ", "Asia/Baku"),
        fallbackArea("BA", "Bosnia and Herzegovina", "BA", "Europe/Sarajevo"),
        fallbackArea("BE", "Belgium", "BE", "Europe/Brussels"),
        fallbackArea("BG", "Bulgaria", "BG", "Europe/Sofia"),
        fallbackArea("CH", "Switzerland", "CH", "Europe/Zurich"),
        fallbackArea("CY", "Cyprus", "CY", "Asia/Nicosia"),
        fallbackArea("CZ", "Czech Republic", "CZ", "Europe/Prague"),
        germanyLuxembourg,
        fallbackArea("DK1", "Denmark West", "DK", "Europe/Copenhagen"),
        fallbackArea("DK2", "Denmark East", "DK", "Europe/Copenhagen"),
        fallbackArea("EE", "Estonia", "EE", "Europe/Tallinn"),
        fallbackArea("ES", "Spain", "ES", "Europe/Madrid"),
        fallbackArea("FI", "Finland", "FI", "Europe/Helsinki"),
        fallbackArea("FR", "France", "FR", "Europe/Paris"),
        fallbackArea("GB", "United Kingdom", "GB", "Europe/London"),
        fallbackArea("GE", "Georgia", "GE", "Asia/Tbilisi"),
        fallbackArea("GR", "Greece", "GR", "Europe/Athens"),
        fallbackArea("HR", "Croatia", "HR", "Europe/Zagreb"),
        fallbackArea("HU", "Hungary", "HU", "Europe/Budapest"),
        fallbackArea("IE(SEM)", "Ireland (SEM)", "IE", "Europe/Dublin"),
        fallbackArea("IT-Brindisi", "Italy Brindisi", "IT", "Europe/Rome"),
        fallbackArea("IT-Calabria", "Italy Calabria", "IT", "Europe/Rome"),
        fallbackArea("IT-Centre-North", "Italy Centre-North", "IT", "Europe/Rome"),
        fallbackArea("IT-Centre-South", "Italy Centre-South", "IT", "Europe/Rome"),
        fallbackArea("IT-Foggia", "Italy Foggia", "IT", "Europe/Rome"),
        fallbackArea("IT-North", "Italy North", "IT", "Europe/Rome"),
        fallbackArea("IT-Priolo", "Italy Priolo", "IT", "Europe/Rome"),
        fallbackArea("IT-Rossano", "Italy Rossano", "IT", "Europe/Rome"),
        fallbackArea("IT-Sardinia", "Italy Sardinia", "IT", "Europe/Rome"),
        fallbackArea("IT-Sicily", "Italy Sicily", "IT", "Europe/Rome"),
        fallbackArea("IT-South", "Italy South", "IT", "Europe/Rome"),
        fallbackArea("LT", "Lithuania", "LT", "Europe/Vilnius"),
        fallbackArea("LV", "Latvia", "LV", "Europe/Riga"),
        fallbackArea("MD", "Moldova", "MD", "Europe/Chisinau"),
        fallbackArea("ME", "Montenegro", "ME", "Europe/Podgorica"),
        fallbackArea("MK", "North Macedonia", "MK", "Europe/Skopje"),
        fallbackArea("MT", "Malta", "MT", "Europe/Malta"),
        fallbackArea("NL", "Netherlands", "NL", "Europe/Amsterdam"),
        fallbackArea("NO1", "Norway NO1", "NO", "Europe/Oslo"),
        fallbackArea("NO2", "Norway NO2", "NO", "Europe/Oslo"),
        fallbackArea("NO3", "Norway NO3", "NO", "Europe/Oslo"),
        fallbackArea("NO4", "Norway NO4", "NO", "Europe/Oslo"),
        fallbackArea("NO5", "Norway NO5", "NO", "Europe/Oslo"),
        fallbackArea("PL", "Poland", "PL", "Europe/Warsaw"),
        fallbackArea("PT", "Portugal", "PT", "Europe/Lisbon"),
        fallbackArea("RO", "Romania", "RO", "Europe/Bucharest"),
        fallbackArea("RS", "Serbia", "RS", "Europe/Belgrade"),
        fallbackArea("SE1", "Sweden SE1", "SE", "Europe/Stockholm"),
        fallbackArea("SE2", "Sweden SE2", "SE", "Europe/Stockholm"),
        fallbackArea("SE3", "Sweden SE3", "SE", "Europe/Stockholm"),
        fallbackArea("SE4", "Sweden SE4", "SE", "Europe/Stockholm"),
        fallbackArea("SI", "Slovenia", "SI", "Europe/Ljubljana"),
        fallbackArea("SK", "Slovakia", "SK", "Europe/Bratislava"),
        fallbackArea("TR", "Turkey", "TR", "Europe/Istanbul"),
        fallbackArea("UA", "Ukraine", "UA", "Europe/Kyiv"),
        fallbackArea("UA-BEI", "Ukraine BEI", "UA", "Europe/Kyiv"),
        fallbackArea("UA-DobTPP", "Ukraine Dobrotvir TPP", "UA", "Europe/Kyiv"),
        fallbackArea("UA-IPS", "Ukraine IPS", "UA", "Europe/Kyiv"),
        fallbackArea("XK", "Kosovo", "XK", "Europe/Belgrade"),
    ]

    static func area(for key: String) -> MarketArea {
        fallbackAreas.first(where: { $0.key == key }) ?? germanyLuxembourg
    }

    static func fetchSupportedAreas() async throws -> SupportedMarketAreasResponse {
        try await APIClient().request(to: APIClient.createSupportedMarketAreasRequest())
    }
}

struct SupportedMarketAreasResponse: Decodable {
    let defaultArea: String
    let areas: [MarketArea]

    enum CodingKeys: String, CodingKey {
        case defaultArea = "default_area"
        case areas
    }
}
