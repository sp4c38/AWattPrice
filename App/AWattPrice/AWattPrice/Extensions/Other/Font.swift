//
//  Font.swift
//  AWattPrice
//
//  Created by Léon Becker on 31.01.21.
//

import SwiftUI

// Font extensions
extension Font {
    /// Fixed text sizes
    static let fTitle = Font.system(size: 26, weight: .regular)
    static let fTitle2 = Font.system(size: 20, weight: .regular)
    static let fHeadline = Font.system(size: 17, weight: .bold)
    static let fSubHeadline = Font.system(size: 15, weight: .regular)
    static let fCallout = Font.system(size: 17, weight: .regular)
    static let fBody = Font.system(size: 16, weight: .regular)
    static let fCaption = Font.system(size: 12, weight: .regular)
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
