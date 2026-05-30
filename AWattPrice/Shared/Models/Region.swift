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
        fallbackArea("AL", "Albania", "AL", "Europe/Tirane", taxMultiplier: 1.20),
        fallbackArea("AM", "Armenia", "AM", "Asia/Yerevan", taxMultiplier: 1.20),
        austria,
        fallbackArea("AZ", "Azerbaijan", "AZ", "Asia/Baku", taxMultiplier: 1.18),
        fallbackArea("BA", "Bosnia and Herzegovina", "BA", "Europe/Sarajevo", taxMultiplier: 1.17),
        fallbackArea("BE", "Belgium", "BE", "Europe/Brussels", taxMultiplier: 1.21),
        fallbackArea("BG", "Bulgaria", "BG", "Europe/Sofia", taxMultiplier: 1.20),
        fallbackArea("CH", "Switzerland", "CH", "Europe/Zurich", taxMultiplier: 1.081),
        fallbackArea("CY", "Cyprus", "CY", "Asia/Nicosia", taxMultiplier: 1.19),
        fallbackArea("CZ", "Czech Republic", "CZ", "Europe/Prague", taxMultiplier: 1.21),
        germanyLuxembourg,
        fallbackArea("DK1", "Denmark West", "DK", "Europe/Copenhagen", taxMultiplier: 1.25),
        fallbackArea("DK2", "Denmark East", "DK", "Europe/Copenhagen", taxMultiplier: 1.25),
        fallbackArea("EE", "Estonia", "EE", "Europe/Tallinn", taxMultiplier: 1.22),
        fallbackArea("ES", "Spain", "ES", "Europe/Madrid", taxMultiplier: 1.21),
        fallbackArea("FI", "Finland", "FI", "Europe/Helsinki", taxMultiplier: 1.255),
        fallbackArea("FR", "France", "FR", "Europe/Paris", taxMultiplier: 1.20),
        fallbackArea("GB", "United Kingdom", "GB", "Europe/London", taxMultiplier: 1.20),
        fallbackArea("GE", "Georgia", "GE", "Asia/Tbilisi", taxMultiplier: 1.18),
        fallbackArea("GR", "Greece", "GR", "Europe/Athens", taxMultiplier: 1.24),
        fallbackArea("HR", "Croatia", "HR", "Europe/Zagreb", taxMultiplier: 1.25),
        fallbackArea("HU", "Hungary", "HU", "Europe/Budapest", taxMultiplier: 1.27),
        fallbackArea("IE(SEM)", "Ireland (SEM)", "IE", "Europe/Dublin", taxMultiplier: 1.23),
        fallbackArea("IT-Brindisi", "Italy Brindisi", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-Calabria", "Italy Calabria", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-Centre-North", "Italy Centre-North", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-Centre-South", "Italy Centre-South", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-Foggia", "Italy Foggia", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-North", "Italy North", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-Priolo", "Italy Priolo", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-Rossano", "Italy Rossano", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-Sardinia", "Italy Sardinia", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-Sicily", "Italy Sicily", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("IT-South", "Italy South", "IT", "Europe/Rome", taxMultiplier: 1.22),
        fallbackArea("LT", "Lithuania", "LT", "Europe/Vilnius", taxMultiplier: 1.21),
        fallbackArea("LV", "Latvia", "LV", "Europe/Riga", taxMultiplier: 1.21),
        fallbackArea("MD", "Moldova", "MD", "Europe/Chisinau", taxMultiplier: 1.20),
        fallbackArea("ME", "Montenegro", "ME", "Europe/Podgorica", taxMultiplier: 1.21),
        fallbackArea("MK", "North Macedonia", "MK", "Europe/Skopje", taxMultiplier: 1.18),
        fallbackArea("MT", "Malta", "MT", "Europe/Malta", taxMultiplier: 1.18),
        fallbackArea("NL", "Netherlands", "NL", "Europe/Amsterdam", taxMultiplier: 1.21),
        fallbackArea("NO1", "Norway NO1", "NO", "Europe/Oslo", taxMultiplier: 1.25),
        fallbackArea("NO2", "Norway NO2", "NO", "Europe/Oslo", taxMultiplier: 1.25),
        fallbackArea("NO3", "Norway NO3", "NO", "Europe/Oslo", taxMultiplier: 1.25),
        fallbackArea("NO4", "Norway NO4", "NO", "Europe/Oslo", taxMultiplier: 1.25),
        fallbackArea("NO5", "Norway NO5", "NO", "Europe/Oslo", taxMultiplier: 1.25),
        fallbackArea("PL", "Poland", "PL", "Europe/Warsaw", taxMultiplier: 1.23),
        fallbackArea("PT", "Portugal", "PT", "Europe/Lisbon", taxMultiplier: 1.23),
        fallbackArea("RO", "Romania", "RO", "Europe/Bucharest", taxMultiplier: 1.19),
        fallbackArea("RS", "Serbia", "RS", "Europe/Belgrade", taxMultiplier: 1.20),
        fallbackArea("SE1", "Sweden SE1", "SE", "Europe/Stockholm", taxMultiplier: 1.25),
        fallbackArea("SE2", "Sweden SE2", "SE", "Europe/Stockholm", taxMultiplier: 1.25),
        fallbackArea("SE3", "Sweden SE3", "SE", "Europe/Stockholm", taxMultiplier: 1.25),
        fallbackArea("SE4", "Sweden SE4", "SE", "Europe/Stockholm", taxMultiplier: 1.25),
        fallbackArea("SI", "Slovenia", "SI", "Europe/Ljubljana", taxMultiplier: 1.22),
        fallbackArea("SK", "Slovakia", "SK", "Europe/Bratislava", taxMultiplier: 1.23),
        fallbackArea("TR", "Turkey", "TR", "Europe/Istanbul", taxMultiplier: 1.20),
        fallbackArea("UA", "Ukraine", "UA", "Europe/Kyiv", taxMultiplier: 1.20),
        fallbackArea("UA-BEI", "Ukraine BEI", "UA", "Europe/Kyiv", taxMultiplier: 1.20),
        fallbackArea("UA-DobTPP", "Ukraine Dobrotvir TPP", "UA", "Europe/Kyiv", taxMultiplier: 1.20),
        fallbackArea("UA-IPS", "Ukraine IPS", "UA", "Europe/Kyiv", taxMultiplier: 1.20),
        fallbackArea("XK", "Kosovo", "XK", "Europe/Belgrade", taxMultiplier: 1.18),
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
