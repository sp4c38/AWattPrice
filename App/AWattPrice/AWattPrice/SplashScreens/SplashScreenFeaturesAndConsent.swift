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
    var imageName: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: imageName)
                .font(.system(size: 40))
                .foregroundColor(Color(hue: 0.5648, saturation: 1.0000, brightness: 0.6235))
                .padding()
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                
                Text(subTitle)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
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
                    .font(.subheadline)
                    .foregroundColor(Color.white)
                    .colorMultiply(getForegroundColor(isText: true))
                
                Button(action: {
                    openAgreementLink(agreementLinks)
                }) {
                    HStack {
                        Text(seeAgreementText.localized())
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(Color.blue)
                }
            }
            
            Spacer()
        }
        .animation(.easeInOut(duration: 0.4))
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
 A splash screen which presents and describes the main functionalities of the app briefly and displays a check box for the user to consent to the apps privacy policy.
 */
struct SplashScreenFeaturesAndConsentView: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var redirectToNextSplashScreen: Int? = 0
    
    @State var termsOfUseIsChecked: Bool = false
    @State var privacyPolicyIsChecked: Bool = false
    
    @State var showTermsOfUseNotChecked: Bool = false
    @State var showPrivacyPolicyNotChecked: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink("", destination: SplashScreenSetupView(), tag: 1, selection: $redirectToNextSplashScreen)
                .frame(width: 0, height: 0)
                .hidden()
            
            VStack(spacing: 30) {
                AppFeatureView(title: "splashScreen.featuresAndConsent.viewPrices", subTitle: "splashScreen.featuresAndConsent.viewPrices.info", imageName: "magnifyingglass")

                AppFeatureView(title: "splashScreen.featuresAndConsent.comparePrices", subTitle: "splashScreen.featuresAndConsent.comparePrices.info", imageName: "arrow.left.arrow.right")
            }

            Spacer()
            
            AgreementConsentView(
                agreeText: "splashScreen.featuresAndConsent.termsOfUse.agree",
                seeAgreementText: "splashScreen.featuresAndConsent.termsOfUse.see",
                agreementLinks: ("https://awattprice.space8.me/terms_of_use/german.html",
                                 "https://awattprice.space8.me/terms_of_use/english.html"),
                isChecked: $termsOfUseIsChecked,
                showConsentNotChecked: $showTermsOfUseNotChecked)
                .padding(.bottom, 25)
            
            AgreementConsentView(
                agreeText: "splashScreen.featuresAndConsent.privacyPolicy.agree",
                seeAgreementText: "splashScreen.featuresAndConsent.privacyPolicy.see",
                agreementLinks: ("https://awattprice.space8.me/privacy_policy/german.html",
                                 "https://awattprice.space8.me/privacy_policy/english.html"),
                isChecked: $privacyPolicyIsChecked,
                showConsentNotChecked: $showPrivacyPolicyNotChecked)
                .padding(.bottom, 25)

            
            Button(action: {
                if privacyPolicyIsChecked == true && termsOfUseIsChecked == true {
                    showTermsOfUseNotChecked = false
                    showPrivacyPolicyNotChecked = false
                    redirectToNextSplashScreen = 1
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
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .padding(.top, 20)
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
