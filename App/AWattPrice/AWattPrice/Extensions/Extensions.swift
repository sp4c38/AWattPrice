//
//  Extensions.swift
//  AwattarApp
//
//  Created by Léon Becker on 25.10.20.
//

import SwiftUI

// View extensions
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
        self.modifier(AnimatableCustomFontModifier(size: size, weight: weight))
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

// String extensions
extension String {
    static let numberFormatter = NumberFormatter()
    
    /// The double value of a string. This supports , and . as seperator. This attribute is nil if the string can't be converted to a double and a double if conversion was successful.
    var doubleValue: Double? {
        String.numberFormatter.decimalSeparator = "."
        
        if let result = String.numberFormatter.number(from: self) {
            return Double(truncating: result)
        } else {
            String.numberFormatter.decimalSeparator = ","
            
            if let result = String.numberFormatter.number(from: self) {
                return Double(truncating: result)
            }
        }
        
        return nil
    }
}

extension Double {
    var priceString: String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
    
        if let result = numberFormatter.string(from: NSNumber(value: self)) {
            return result
        } else {
            return nil
        }
    }
}

extension String {
    /// Returns the localized string of a string.
    /// If you wish to format a localized string use String(format: String.localized(), value)
    func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }
}


