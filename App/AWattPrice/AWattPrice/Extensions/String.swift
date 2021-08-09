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
    func removeOutOfString(atIndex index: Int) -> String {
        var before = ""
        if index - 1 >= 0 {
            before = String(self[...self.index(startIndex, offsetBy: index - 1)])
        }
        let after = String(self[self.index(startIndex, offsetBy: index + 1)...])
        let newString = before + after
        return newString
    }
}

extension String {
    func addAtIndex(atIndex index: Int, add addString: String) -> String {
        var before = ""
        if index - 1 >= 0 {
            before = String(self[...self.index(startIndex, offsetBy: index - 1)])
        }
        let after = String(self[self.index(startIndex, offsetBy: index)...])
        let newString = before + addString + after
        return newString
    }
}

extension String {
    /// Returns the localized string of a string.
    /// If you wish to format a localized string use String(format: String.localized(), value)
    func localized() -> String {
        NSLocalizedString(self, comment: "")
    }
}

extension String {
    func part(inRange range: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(startIndex, offsetBy: range.upperBound)
        
        let range = start..<end
        return String(self[range])
    }
}
    
extension String {
    var completeNSRange: NSRange {
        let range = NSRange(location: 0, length: self.utf16.count)
        return range
    }
}
