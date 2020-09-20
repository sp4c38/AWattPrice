//
//  ButtonStyles.swift
//  AwattarApp
//
//  Created by Léon Becker on 20.09.20.
//

import SwiftUI

struct DoneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
    }
}
