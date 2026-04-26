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
    let fixedPriceAddOn: Double
    let percentagePriceAddOn: Double
    let marketArea: MarketArea
}

@Model
public class Setting {
    // General attributes
    var baseFeePrice: Double = 0.0
    var taxEnabled: Bool = true
    var marketAreaKey: String = MarketArea.defaultAreaKey
    var regulatedPriceAddOn: Double = 0.0
    var percentagePriceAddOn: Double = 0.0
    var monthlyFixedCost: Double = 0.0
    var annualConsumptionKWh: Double = 3500.0
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

    var monthlyFixedCostPrice: Double {
        guard monthlyFixedCost > 0, annualConsumptionKWh > 0 else { return 0 }
        return monthlyFixedCost * 12 * 100 / annualConsumptionKWh
    }

    var totalPriceAddOn: Double {
        baseFeePrice + monthlyFixedCostPrice
    }

    var pricingConfiguration: PricingConfiguration {
        PricingConfiguration(
            fixedPriceAddOn: totalPriceAddOn,
            percentagePriceAddOn: percentagePriceAddOn,
            marketArea: marketArea
        )
    }
}
