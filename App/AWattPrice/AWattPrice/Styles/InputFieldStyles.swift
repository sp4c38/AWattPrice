//
//  InputFieldStyles.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.01.21.
//

import SwiftUI

struct GeneralInputView: ViewModifier {
    let markedRed: Bool
    init(markedRed: Bool) {
        self.markedRed = markedRed
    }
    
    func body(content: Content) -> some View {
        content
        .padding(.leading, 17)
        .padding(.trailing, 14)
        .padding([.top, .bottom], 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    markedRed ?
                        Color.red :
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706), lineWidth: 2
                )
        )
    }
}

struct InputFieldStyles_Previews: PreviewProvider {
    static var previews: some View {
        Text("Some Text")
            .modifier(GeneralInputView(markedRed: true))
    }
}
