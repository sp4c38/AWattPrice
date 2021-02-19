//
//  General.swift
//  AwattarApp
//
//  Created by Léon Becker on 25.10.20.
//

// General extensions

import SwiftUI

extension View {
    /// Applies modifiers only than to the content if a conditional evaluates to true
    @ViewBuilder func ifTrue<Content: View>(_ conditional: Bool, content: (Self) -> Content) -> some View {
        if conditional {
            content(self)
        } else {
            self
        }
    }
}

// AnyTransition extensions
extension AnyTransition {
    /// A transition used for presenting a view with extra information to the screen.
    static var extraInformationTransition: AnyTransition {
        let insertion = AnyTransition.opacity // AnyTransition.scale(scale: 2).combined(with: .opacity)
        let removal = AnyTransition.opacity // AnyTransition.scale(scale: 2).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

// Basic types extensions
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

    var integerValue: Int? {
        let numberFormatter = NumberFormatter()

        if let result = numberFormatter.number(from: self) {
            return Int(truncating: result)
        }

        return nil
    }

    func removeOutOfString(atIndex index: Int) -> String {
        var before = ""
        if index - 1 >= 0 {
            before = String(self[...self.index(startIndex, offsetBy: index - 1)])
        }
        let after = String(self[self.index(startIndex, offsetBy: index + 1)...])
        let newString = before + after
        return newString
    }

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
     
    var completeNSRange: NSRange {
        let range = NSRange(location: 0, length: self.utf16.count)
        return range
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
}

extension Int {
    var priceString: String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none

        if let result = numberFormatter.string(from: NSNumber(value: self)) {
            return result
        } else {
            return nil
        }
    }
}

extension NSRegularExpression {
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }
    
    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        let matches = firstMatch(in: string, options: [], range: range) != nil
        return matches
    }
}
