//
//  ButtonStyles.swift
//  AwattarApp
//
//  Created by Léon Becker on 20.09.20.
//

import SwiftUI


struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1))
    }
}

struct ContinueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hue: 0.6500, saturation: 0.6195, brightness: 0.8863))
            .cornerRadius(11)
    }
}

struct TimeRangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(7)
            .padding([.leading, .trailing], 4)
            .foregroundColor(Color.white)
            .background(Color.blue)
            .cornerRadius(7)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .ifTrue(configuration.isPressed) { content in
                content.animation(.easeInOut(duration: 0.1))
            }
//            .animation(.easeInOut(duration: 0.1))
    }
}
