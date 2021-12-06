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
    
    enum CodingKeys: CodingKey {
        case region, tax
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(region.apiName, forKey: .region)
        try container.encode(tax, forKey: .tax)
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
        _ token: String?, _ currentSetting: CurrentSetting, _ notificationSetting: CurrentNotificationSetting
    ) -> NotificationConfiguration {
        let currentEntity = currentSetting.entity!
        let notificationEntity = notificationSetting.entity!
        let selectedRegion = Region(rawValue: currentEntity.regionIdentifier)!
        
        let general = GeneralNotificationConfiguration(region: selectedRegion, tax: currentEntity.pricesWithVAT)
        let priceBelowNotification = PriceBelowNotificationNotificationConfiguration(
            active: notificationEntity.priceDropsBelowValueNotification, belowValue: notificationEntity.priceBelowValue
        )
        let notifications = NotificationsNotificationConfiguration(priceBelow: priceBelowNotification)
        
        return NotificationConfiguration(token: token, general: general, notifications: notifications)
    }
}
