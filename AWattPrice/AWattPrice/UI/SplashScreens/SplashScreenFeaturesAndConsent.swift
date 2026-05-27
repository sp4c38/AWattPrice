//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//


import SwiftUI
import UIKit

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

/**
 Single detail view to show a icon, title and subtitle intended to describe a main functionality of the app.
 */
struct AppFeatureView: View {
    @Environment(\.colorScheme) var colorScheme

    var title: LocalizedStringKey
    var subTitle: LocalizedStringKey
    var tipText: LocalizedStringKey? = nil
    /// Tuple out of String (1st item) and Bool (2nd item). 2nd item tells if image should be resolved as a SF icon.
    var imageName: (String, Bool)

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .center, spacing: 10) {
                    VStack {
                        if imageName.1 == true {
                            Image(systemName: imageName.0)
                                .resizable()
                                .renderingMode(.template)
                        } else {
                            Image(imageName.0)
                                .resizable()
                                .renderingMode(.template)
                        }
                    }
                    .foregroundColor(Color(hue: 0.5648, saturation: 1.0000, brightness: 0.6235))
                    .padding(16)
                    .frame(width: 70, height: 70)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.fHeadline)
                            .bold()
                            .foregroundColor(colorScheme == .light ? Color.black : Color.white)

                        Text(subTitle)
                            .font(.fSubHeadline)
                            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if tipText != nil {
                    Text(tipText!)
                        .foregroundColor(Color.gray)
                        .font(.fSubHeadline)
                        .padding(.top, 10)
                        .padding(.leading, 80)
                }
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }
}

/**
 A splash screen which presents and describes the main functionalities of the app
 briefly before the user continues to setup.
 */
struct SplashScreenFeaturesAndConsentView: View {
    @State private var showsSetup = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Text("What AWattPrice does")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                AppFeatureView(
                    title: "Tomorrow’s prices",
                    subTitle: "splashScreen.featuresAndConsent.viewPrices.info",
                    imageName: ("magnifyingglass", true)
                )

                AppFeatureView(
                    title: "Best usage windows",
                    subTitle: "splashScreen.featuresAndConsent.comparePrices.info",
                    imageName: ("arrow.left.arrow.right", true)
                )

                AppFeatureView(
                    title: "Price alerts",
                    subTitle: "notificationPage.notification.priceDropsBelowValue.description",
                    imageName: ("PriceTag", false)
                )
            }

            Spacer(minLength: 0)

            Button(action: {
                showsSetup = true
            }) {
                Text("Continue")
                    .font(.fBody)
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .padding(.top, 12)
        .padding([.leading, .trailing], 20)
        .padding(.bottom, 16)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsSetup) {
            SplashScreenSetupView()
        }
    }
}

struct SplashScreenFeaturesAndConsentView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenFeaturesAndConsentView()
            .preferredColorScheme(.light)
    }
}
