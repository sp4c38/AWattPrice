//
//  Extensions.swift
//  AwattarApp
//
//  Created by Léon Becker on 25.10.20.
//

// General extensions

import SwiftUI

extension View {
    /// Hides the keyboard from the screen
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

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

struct AnimatableCustomFontModifier: AnimatableModifier {
    var size: CGFloat
    var weight: Font.Weight

    var animatableData: CGFloat {
        get { size }
        set {
            size = newValue
        }
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
    }
}

extension View {
    /**
     Animates size changes of text
     - Parameter size: The size of the text. If it gets changed those changes in text size are animated.
     - Returns: Returns the view the modifier was applied to with the font  and properties to reflect the change of the size to animate it in the future.
     */
    func animatableFont(size: CGFloat, weight: Font.Weight) -> some View {
        modifier(AnimatableCustomFontModifier(size: size, weight: weight))
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
