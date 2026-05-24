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
    let orderedAddOns: [PriceAddOnConfiguration]
    let marketArea: MarketArea
}

enum PriceAddOnKind: String, CaseIterable, Codable, Hashable, Sendable {
    case fixed
    case percentage
    case monthly
}

struct PriceAddOnConfiguration: Hashable, Sendable {
    let kind: PriceAddOnKind
    let value: Double
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
    var priceAddOnOrder: String = "fixed,percentage,monthly"
    var onboarded: Bool = false // Splash screens finished
    
    // Notification attributes
    var pushToken: String?
    var priceDropsBelowThreshold: Int = 0
    var priceDropsBelowEnabled: Bool = false
    var priceRisesAboveThreshold: Int = 0
    var priceRisesAboveEnabled: Bool = false
    var dailySummaryEnabled: Bool = false
    
    
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
            orderedAddOns: orderedPriceAddOns,
            marketArea: marketArea
        )
    }

    var orderedPriceAddOnKinds: [PriceAddOnKind] {
        get {
            let savedOrder = priceAddOnOrder
                .split(separator: ",")
                .compactMap { PriceAddOnKind(rawValue: String($0)) }
            return Self.normalizedPriceAddOnOrder(savedOrder)
        }
        set {
            priceAddOnOrder = Self.normalizedPriceAddOnOrder(newValue)
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    var orderedPriceAddOns: [PriceAddOnConfiguration] {
        orderedPriceAddOnKinds.compactMap { kind in
            switch kind {
            case .fixed:
                guard baseFeePrice != 0 else { return nil }
                return PriceAddOnConfiguration(kind: kind, value: baseFeePrice)
            case .percentage:
                guard percentagePriceAddOn != 0 else { return nil }
                return PriceAddOnConfiguration(kind: kind, value: percentagePriceAddOn)
            case .monthly:
                guard monthlyFixedCostPrice != 0 else { return nil }
                return PriceAddOnConfiguration(kind: kind, value: monthlyFixedCostPrice)
            }
        }
    }

    static func normalizedPriceAddOnOrder(_ order: [PriceAddOnKind]) -> [PriceAddOnKind] {
        var result: [PriceAddOnKind] = []
        for kind in order where result.contains(kind) == false {
            result.append(kind)
        }
        for kind in PriceAddOnKind.allCases where result.contains(kind) == false {
            result.append(kind)
        }
        return result
    }
}

extension Setting {
    var activeNotificationRuleCount: Int {
        var count = 0
        if priceDropsBelowEnabled { count += 1 }
        if priceRisesAboveEnabled { count += 1 }
        if dailySummaryEnabled { count += 1 }
        return count
    }
}
