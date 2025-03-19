//
//  NotificationSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.03.25.
//
//

import Foundation
import SwiftData

@Model
public class NotificationSetting {
    var pushToken: String?
    var priceThreshold: Int64 = 0
    var priceDropsBelowEnabled: Bool = false
    
    public init() {
        // Empty initializer - property defaults are set above
    }
}
