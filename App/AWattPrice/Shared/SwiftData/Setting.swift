//
//  Setting.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.03.25.
//
//

import Foundation
import SwiftData

@Model
public class Setting {
    // General attributes
    var baseFeePrice: Double = 0.0
    var taxEnabled: Bool = true
    var region: Region = Region.DE
    var onboarded: Bool = false // Splash screens finished
    
    // Notification attributes
    var pushToken: String?
    var priceDropsBelowThreshold: Int = 0
    var priceDropsBelowEnabled: Bool = false
    
    
    public init() {
        // Empty initializer - property defaults are set above
    }
}
