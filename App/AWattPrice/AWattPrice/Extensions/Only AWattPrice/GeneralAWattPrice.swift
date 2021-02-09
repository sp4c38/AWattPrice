//
//  General.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.02.21.
//

import SwiftUI

extension View {
    /// Hides the keyboard from the screen
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
