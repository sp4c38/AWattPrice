//
//  ButtonStyles.swift
//  AwattarApp
//
//  Created by Léon Becker on 20.09.20.
//

import SwiftUI
import UIKit

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.subheadline.bold())
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.accent)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

struct ContinueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.fBody.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.48, blue: 0.68),
                        Color(red: 0.08, green: 0.26, blue: 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .shadow(color: Color(red: 0.03, green: 0.40, blue: 0.80).opacity(configuration.isPressed ? 0.18 : 0.32), radius: configuration.isPressed ? 8 : 16, y: configuration.isPressed ? 4 : 9)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
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
            .background(AppTheme.accent)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(configuration.isPressed ? .easeInOut(duration: 0.1) : nil, value: configuration.isPressed)
    }
}

struct RetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? AppTheme.accent : Color.gray)
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 40)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(configuration.isPressed ? AppTheme.accent : Color.gray)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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

/// Opens the apps privacy policy in the browser in the correct language depending on the device language.
func openAgreementLink(_ agreementLinks: (String, String)) {
    var agreementLink = URL(string: agreementLinks.0)

    if Locale.current.language.languageCode?.identifier == "en" {
        agreementLink = URL(string: agreementLinks.1)
    }

    if agreementLink != nil {
        if agreementLink!.absoluteString != "" {
            UIApplication.shared.open(agreementLink!)
        }
    }
}
