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
    var belowValue: Int
    
    enum CodingKeys: String, CodingKey {
        case active
        case belowValue = "below_value"
    }
}

struct NotificationsNotificationConfiguration: Encodable {
    var priceBelow: PriceBelowNotificationNotificationConfiguration
    
    enum CodingKeys: String, CodingKey {
        case priceBelow = "price_below"
    }
}

struct NotificationConfiguration: Encodable {
    var token: String?
    var general: GeneralNotificationConfiguration
    var notifications: NotificationsNotificationConfiguration
    
    static func create(_ token: String?, _ setting: Setting) -> NotificationConfiguration {
        let general = GeneralNotificationConfiguration(
            marketArea: setting.marketArea,
            tax: true,
            baseFee: setting.totalPriceAddOn,
            percentageAddOn: setting.percentagePriceAddOn
        )
        let priceBelowNotification = PriceBelowNotificationNotificationConfiguration(
            active: setting.priceDropsBelowEnabled, belowValue: Int(setting.priceDropsBelowThreshold)
        )
        let notifications = NotificationsNotificationConfiguration(priceBelow: priceBelowNotification)
        
        return NotificationConfiguration(token: token, general: general, notifications: notifications)
    }
}
