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
            .font(Font.fSubHeadline.bold())
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut)
    }
}

struct ContinueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.fBody.bold())
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(11)
    }
}

struct TimeRangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 10)
            .foregroundColor(Color.white)
            .background(Color.blue)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .ifTrue(configuration.isPressed) { content in
                content.animation(.easeInOut(duration: 0.1))
            }
    }
}

struct RetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Color.blue : Color.gray)
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 40)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(configuration.isPressed ? Color.blue : Color.gray)
            )
            .animation(.easeInOut(duration: 0.1))
    }
}

struct RoundedBorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(Color.gray)
            .padding([.top, .bottom], 6)
            .padding([.leading, .trailing], 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, lineWidth: 0.5)
            )
    }
}

struct TimeRangeButtonStyle_Preview: PreviewProvider {
    static var previews: some View {
        Button(action: {}) {
            Text("maximal")
                .fontWeight(.semibold)
        }
        .buttonStyle(TimeRangeButtonStyle())
    }
}
