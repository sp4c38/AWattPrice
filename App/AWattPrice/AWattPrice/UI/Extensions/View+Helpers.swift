//
//  View+Helpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.08.21.
//

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
