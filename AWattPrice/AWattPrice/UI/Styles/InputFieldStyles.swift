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
            return Color.red
        } else {
            if colorScheme == .light {
                return
                    Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706)
            } else {
                return
                    Color(hue: 0.0000, saturation: 0.0000, brightness: 0.3706)
            }
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
