//
//  NotificationConfiguration.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Foundation

struct GeneralNotificationConfiguration: Encodable {
    var region: Region
    var tax: Bool
    var baseFee: Double
    
    enum CodingKeys: String, CodingKey {
        case region, tax
        case baseFee = "base_fee"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(region.apiName, forKey: .region)
        try container.encode(tax, forKey: .tax)
        try container.encode(baseFee, forKey: .baseFee)
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
    
    static func create(
        _ token: String?, _ setting: SettingCoreData, _ notificationSetting: NotificationSettingCoreData
    ) -> NotificationConfiguration {
        let selectedRegion = Region(rawValue: setting.entity.regionIdentifier)!
        
        let general = GeneralNotificationConfiguration(region: selectedRegion, tax: setting.entity.pricesWithVAT, baseFee: setting.entity.baseFee)
        let priceBelowNotification = PriceBelowNotificationNotificationConfiguration(
            active: notificationSetting.entity.priceDropsBelowValueNotification, belowValue: Int(notificationSetting.entity.priceBelowValue)
        )
        let notifications = NotificationsNotificationConfiguration(priceBelow: priceBelowNotification)
        
        return NotificationConfiguration(token: token, general: general, notifications: notifications)
    }
}
