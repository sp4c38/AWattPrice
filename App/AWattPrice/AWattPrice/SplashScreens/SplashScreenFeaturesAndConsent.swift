//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

/// Opens the apps privacy policy in the browser in the correct language depending on the device language.
func openAgreementLink(_ agreementLinks: (String, String)) {
    var agreementLink = URL(string: agreementLinks.0)

    if Locale.current.languageCode == "en" {
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

struct AgreementConsentView: View {
    @Environment(\.colorScheme) var colorScheme

    var agreeText: String
    var seeAgreementText: String
    var agreementLinks: (String, String) // First item is the default link, second item is the link when the device language is english

    @Binding var isChecked: Bool
    @Binding var showConsentNotChecked: Bool

    func getForegroundColor(isCheckmark: Bool = false, isText: Bool = false) -> Color {
        if showConsentNotChecked == true && (isCheckmark == true || isText == true) {
            return Color.red
        }

        if isCheckmark {
            return Color.blue
        }

        if colorScheme == .light {
            return Color.black
        } else {
            return Color.white
        }
    }

    var body: some View {
        HStack(spacing: 24) {
            if isChecked == true {
                Image(systemName: "checkmark.square")
                    .resizable()
                    .foregroundColor(Color.white)
                    .colorMultiply(getForegroundColor(isCheckmark: true))
                    .frame(width: 27, height: 27)
                    .transition(.opacity)
            } else {
                Image(systemName: "square")
                    .resizable()
                    .foregroundColor(Color.white)
                    .colorMultiply(getForegroundColor(isCheckmark: true))
                    .frame(width: 27, height: 27)
                    .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(agreeText.localized())
                    .font(.fSubHeadline)
                    .foregroundColor(Color.white)
                    .colorMultiply(getForegroundColor(isText: true))

                Button(action: {
                    openAgreementLink(agreementLinks)
                }) {
                    HStack {
                        Text(seeAgreementText.localized())
                        Image(systemName: "chevron.right")
                    }
                    .font(.fSubHeadline)
                    .foregroundColor(Color.blue)
                }
            }

            Spacer()
        }
        .animation(.none)
        .contentShape(Rectangle())
        .onTapGesture {
            isChecked.toggle()
            if isChecked == true {
                showConsentNotChecked = false
            }
        }
    }
}

/**
 A splash screen which presents and describes the main functionalities of the app
 briefly and displays a check box for the user to consent to the apps privacy policy.
 */
struct SplashScreenFeaturesAndConsentView: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var notificationAccess: NotificationAccess

    @State var privacyPolicyIsChecked: Bool = false
    @State var redirectToNextSplashScreen: Int? = 0
    @State var showPrivacyPolicyNotChecked: Bool = false
    @State var showTermsOfUseNotChecked: Bool = false
    @State var termsOfUseIsChecked: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink("", destination: SplashScreenSetupView(), tag: 1, selection: $redirectToNextSplashScreen)
                .frame(width: 0, height: 0)
                .hidden()

            VStack(spacing: 15) {
                AppFeatureView(
                    title: "splashScreen.featuresAndConsent.viewPrices",
                    subTitle: "splashScreen.featuresAndConsent.viewPrices.info",
                    imageName: ("magnifyingglass", true)
                )

                AppFeatureView(
                    title: "splashScreen.featuresAndConsent.comparePrices",
                    subTitle: "splashScreen.featuresAndConsent.comparePrices.info",
                    imageName: ("arrow.left.arrow.right", true)
                )

                AppFeatureView(
                    title: "general.priceGuard",
                    subTitle: "notificationPage.notification.priceDropsBelowValue.description",
                    imageName: ("PriceTag", false)
                )
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                AgreementConsentView(
                    agreeText: "splashScreen.featuresAndConsent.termsOfUse.agree",
                    seeAgreementText: "general.view",
                    agreementLinks: ("https://awattprice.space8.me/terms_of_use/german.html",
                                     "https://awattprice.space8.me/terms_of_use/english.html"),
                    isChecked: $termsOfUseIsChecked,
                    showConsentNotChecked: $showTermsOfUseNotChecked
                )

                AgreementConsentView(
                    agreeText: "splashScreen.featuresAndConsent.privacyPolicy.agree",
                    seeAgreementText: "general.view",
                    agreementLinks: ("https://awattprice.space8.me/privacy_policy/german.html",
                                     "https://awattprice.space8.me/privacy_policy/english.html"),
                    isChecked: $privacyPolicyIsChecked,
                    showConsentNotChecked: $showPrivacyPolicyNotChecked
                )
            }
            .padding(.bottom, 15)

            Button(action: {
                if privacyPolicyIsChecked == true, termsOfUseIsChecked == true {
                    showTermsOfUseNotChecked = false
                    showPrivacyPolicyNotChecked = false
                    managePushNotificationsOnAppAppear(notificationAccessRepresentable: notificationAccess, registerForRemoteNotifications: true) {
                        redirectToNextSplashScreen = 1
                    }
                } else {
                    if termsOfUseIsChecked == false {
                        showTermsOfUseNotChecked = true
                    }

                    if privacyPolicyIsChecked == false {
                        showPrivacyPolicyNotChecked = true
                    }
                }
            }) {
                Text("general.continue")
                    .font(.fBody)
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .padding(.top, 5)
        .padding([.leading, .trailing], 20)
        .padding(.bottom, 16)
        .navigationBarTitle("splashScreen.featuresAndConsent.features")
    }
}

struct SplashScreenFeaturesAndConsentView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenFeaturesAndConsentView()
            .preferredColorScheme(.light)
    }
}
