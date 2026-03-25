//
//  Setting.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.03.25.
//
//

import Foundation
import SwiftData

struct PricingConfiguration: Sendable {
    let baseFeePrice: Double
    let marketArea: MarketArea
}

@Model
public class Setting {
    // General attributes
    var baseFeePrice: Double = 0.0
    var taxEnabled: Bool = true
    var marketAreaKey: String = MarketArea.defaultAreaKey
    var onboarded: Bool = false // Splash screens finished
    
    // Notification attributes
    var pushToken: String?
    var priceDropsBelowThreshold: Int = 0
    var priceDropsBelowEnabled: Bool = false
    
    
    public init() {
        // Empty initializer - property defaults are set above
    }

    var marketArea: MarketArea {
        get { MarketArea.area(for: marketAreaKey) }
        set { marketAreaKey = newValue.key }
    }

    var pricingConfiguration: PricingConfiguration {
        PricingConfiguration(
            baseFeePrice: baseFeePrice,
            marketArea: marketArea
        )
    }
}
