//
//  Double.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.08.21.
//

import Foundation

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
}
