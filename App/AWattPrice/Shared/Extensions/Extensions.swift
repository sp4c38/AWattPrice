//
//  Calendar.swift
//  AWattPrice
//
//  Created by Léon Becker on 08.02.21.
//

import Foundation

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
