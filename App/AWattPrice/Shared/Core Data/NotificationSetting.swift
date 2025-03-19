//
//  NotificationSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.03.25.
//
//

import Foundation
import SwiftData


@Model public class NotificationSetting {
    var changesButErrorUploading: Bool?
    var forceUpload: Bool? = false
    var lastApnsToken: String?
    var priceBelowValue: Int64? = 0.0
    var priceDropsBelowValueNotification: Bool?
    public init() {

    }
    
}
