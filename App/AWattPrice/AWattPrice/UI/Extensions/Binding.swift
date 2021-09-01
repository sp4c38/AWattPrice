//
//  Binding.swift
//  Binding
//
//  Created by Léon Becker on 01.09.21.
//

import SwiftUI

extension Binding {
    /// Perform code to set a new value.
    func setNewValue(execute: @escaping (Value) -> Void) -> Binding {
        return Binding(
            get: { self.wrappedValue },
            set: { execute($0) }
        )
    }
}
