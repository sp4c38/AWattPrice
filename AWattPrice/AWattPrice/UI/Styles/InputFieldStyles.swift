//
//  InputFieldStyles.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.01.21.
//

import SwiftUI

struct GeneralInputView: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    let markedRed: Bool
    init(markedRed: Bool) {
        self.markedRed = markedRed
    }

    func getBorderColor() -> Color {
        if markedRed {
            return AppTheme.error
        } else {
            return AppTheme.cardStroke(for: colorScheme)
        }
    }

    func body(content: Content) -> some View {
        content
            .padding([.leading, .trailing], 14)
            .padding([.top, .bottom], 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(getBorderColor(), lineWidth: 2)
            )
    }
}

struct InputFieldStyles_Previews: PreviewProvider {
    static var previews: some View {
        Text("Some long input text")
            .modifier(GeneralInputView(markedRed: false))
            .preferredColorScheme(.dark)
    }
}
