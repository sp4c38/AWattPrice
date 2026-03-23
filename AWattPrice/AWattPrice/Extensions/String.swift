//
//  String.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.08.21.
//

import Foundation

extension String {
    /// The double value of a string. This supports , and . as seperator. This attribute is nil if the string can't be converted to a double and a double if conversion was successful.
    var doubleValue: Double? {
        let numberFormatter = NumberFormatter()

        numberFormatter.groupingSeparator = Locale.current.groupingSeparator
        numberFormatter.decimalSeparator = Locale.current.decimalSeparator
        numberFormatter.numberStyle = .decimal

        if let result = numberFormatter.number(from: self) {
            return Double(truncating: result)
        } else {
            if numberFormatter.decimalSeparator == "." {
                numberFormatter.decimalSeparator = ","
            } else {
                numberFormatter.decimalSeparator = "."
            }

            if numberFormatter.groupingSeparator == "." {
                numberFormatter.groupingSeparator = ","
            } else {
                numberFormatter.groupingSeparator = "."
            }

            if let result = numberFormatter.number(from: self) {
                return Double(truncating: result)
            }
        }

        return nil
    }
}

extension String {
    var integerValue: Int? {
        let numberFormatter = NumberFormatter()

        if let result = numberFormatter.number(from: self) {
            return Int(truncating: result)
        }

        return nil
    }
}

extension String {
    /// Returns the localized string of a string.
    /// If you wish to format a localized string use String(format: String.localized(), value)
    func localized() -> String {
        NSLocalizedString(self, comment: "")
    }
}
