//
//  Calendar.swift
//  AWattPrice
//
//  Created by Léon Becker on 08.02.21.
//

import Foundation

let pricesWidgetKind = "AWattPriceWidget.PricesWidget"
let internalAppGroupIdentifier = "group.me.space8.AWattPrice.internal"

extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let hours = self.component(.hour, from: date)
        return self.date(bySettingHour: hours, minute: 0, second: 0, of: date)!
    }
}

extension Double {
    var priceString: String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2

        let currentSelfDouble = (self * 100).rounded() / 100

        if ((currentSelfDouble * 100).rounded() / 100) == 0 {
            return ""
        } else if let result = numberFormatter.string(from: NSNumber(value: currentSelfDouble)) {
            return result
        } else {
            return nil
        }
    }
    
    var euroMWhToCentkWh: Double { self / 1000 * 100 }
}

/// Checks if the current code is executed by the main app.
///
/// - Returns: True if code is executed by main app. False if code is executed for example by an app extension.
func environmentIsMainApp() -> Bool {
    let bundleURL = Bundle.main.bundleURL
    let bundlePathExtension = bundleURL.pathExtension
    let isAppex = bundlePathExtension == "appex"
    if isAppex {
        return false
    } else {
        return true
    }
}
