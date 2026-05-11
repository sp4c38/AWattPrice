//
//  NotificationConfiguration.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Foundation

struct GeneralNotificationConfiguration: Encodable {
    var marketArea: MarketArea
    var tax: Bool
    var baseFee: Double
    var percentageAddOn: Double
    
    enum CodingKeys: String, CodingKey {
        case area, tax
        case baseFee = "base_fee"
        case percentageAddOn = "percentage_add_on"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(marketArea.key, forKey: .area)
        try container.encode(tax, forKey: .tax)
        try container.encode(baseFee, forKey: .baseFee)
        try container.encode(percentageAddOn, forKey: .percentageAddOn)
    }
}

struct PriceBelowNotificationNotificationConfiguration: Encodable {
    var active: Bool
    var threshold: Int?
    
    enum CodingKeys: String, CodingKey {
        case active
        case threshold
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(active, forKey: .active)
        if let threshold {
            try container.encode(threshold, forKey: .threshold)
        } else {
            try container.encodeNil(forKey: .threshold)
        }
    }
}

struct PriceAboveNotificationConfiguration: Encodable {
    var active: Bool
    var threshold: Int?

    enum CodingKeys: String, CodingKey {
        case active
        case threshold
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(active, forKey: .active)
        if let threshold {
            try container.encode(threshold, forKey: .threshold)
        } else {
            try container.encodeNil(forKey: .threshold)
        }
    }
}

struct DailySummaryNotificationConfiguration: Encodable {
    var active: Bool
}

struct NotificationRulesConfiguration: Encodable {
    var priceBelow: PriceBelowNotificationNotificationConfiguration
    var priceAbove: PriceAboveNotificationConfiguration
    var dailySummary: DailySummaryNotificationConfiguration

    enum CodingKeys: String, CodingKey {
        case priceBelow = "price_below"
        case priceAbove = "price_above"
        case dailySummary = "daily_summary"
    }
}

struct NotificationConfiguration: Encodable {
    var token: String?
    var general: GeneralNotificationConfiguration
    var rules: NotificationRulesConfiguration
    
    static func create(_ token: String?, _ setting: Setting) -> NotificationConfiguration {
        let general = GeneralNotificationConfiguration(
            marketArea: setting.marketArea,
            tax: true,
            baseFee: setting.totalPriceAddOn,
            percentageAddOn: setting.percentagePriceAddOn
        )
        let priceBelowNotification = PriceBelowNotificationNotificationConfiguration(
            active: setting.priceDropsBelowEnabled,
            threshold: setting.priceDropsBelowEnabled ? Int(setting.priceDropsBelowThreshold) : nil
        )
        let priceAboveNotification = PriceAboveNotificationConfiguration(
            active: setting.priceRisesAboveEnabled,
            threshold: setting.priceRisesAboveEnabled ? Int(setting.priceRisesAboveThreshold) : nil
        )
        let dailySummaryNotification = DailySummaryNotificationConfiguration(active: setting.dailySummaryEnabled)
        let rules = NotificationRulesConfiguration(
            priceBelow: priceBelowNotification,
            priceAbove: priceAboveNotification,
            dailySummary: dailySummaryNotification
        )
        
        return NotificationConfiguration(token: token, general: general, rules: rules)
    }
}

enum NotificationRuleType: String {
    case priceBelow = "price_below"
    case priceAbove = "price_above"
    case dailySummary = "daily_summary"
}

struct NotificationExampleResponse: Decodable {
    let wouldSend: Bool
    let titleLocKey: String?
    let bodyLocKey: String?
    let locArgs: [String]

    enum CodingKeys: String, CodingKey {
        case wouldSend = "would_send"
        case titleLocKey = "title_loc_key"
        case bodyLocKey = "body_loc_key"
        case locArgs = "loc_args"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        wouldSend = try values.decode(Bool.self, forKey: .wouldSend)
        titleLocKey = try values.decodeIfPresent(String.self, forKey: .titleLocKey)
        bodyLocKey = try values.decodeIfPresent(String.self, forKey: .bodyLocKey)
        locArgs = try values.decodeIfPresent([String].self, forKey: .locArgs) ?? []
    }
}
