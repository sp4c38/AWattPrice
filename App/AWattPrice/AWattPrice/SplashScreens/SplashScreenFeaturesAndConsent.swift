//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

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
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                
                Text(subTitle)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            }
            
            Spacer()
        }
    }
}

struct PrivacyPolicyConsentView: View {
    @Environment(\.colorScheme) var colorScheme
    
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
        HStack(spacing: 20) {
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
                Text("agreePrivacyPolicy")
                    .font(.subheadline)
                    .foregroundColor(Color.white)
                    .colorMultiply(getForegroundColor(isText: true))
                
                Button(action: {
                    var privacyPolicyUrl = URL(string: "https://awattprice.space8.me/privacy_policy_german.html")
                    if Locale.current.languageCode == "de" {
                        privacyPolicyUrl = URL(string: "https://awattprice.space8.me/privacy_policy_german.html")
                    } else if Locale.current.languageCode == "en" {
                        privacyPolicyUrl = URL(string: "https://awattprice.space8.me/privacy_policy_english.html")
                    }

                    if privacyPolicyUrl != nil {
                        UIApplication.shared.open(privacyPolicyUrl!)
                    }
                }) {
                    HStack {
                        Text("seePrivacyPolicy")
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
    
    @State var consentIsChecked: Bool = false
    @State var showConsentNotChecked: Bool = false
    
    var body: some View {
        VStack(spacing: 25) {
            VStack(spacing: 30) {
                AppFeatureView(title: "splashScreenViewPrices", subTitle: "splashScreenViewPricesInfo", imageName: "magnifyingglass")

                AppFeatureView(title: "splashScreenComparePrices", subTitle: "splashScreenComparePricesInfo", imageName: "arrow.left.arrow.right")
            }

            Spacer()
            
            PrivacyPolicyConsentView(isChecked: $consentIsChecked, showConsentNotChecked: $showConsentNotChecked)
            
            Button(action: {
                if consentIsChecked == true {
                    showConsentNotChecked = false
                    currentSetting.changeSplashScreenFinished(newState: true)
                } else {
                    showConsentNotChecked = true
                }
            }) {
                Text("continue")
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .padding(.top, 20)
        .padding([.leading, .trailing], 20)
        .padding(.bottom, 16)
        .navigationBarTitle("features")
    }
}

struct SplashScreenFeaturesAndConsentView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenFeaturesAndConsentView()
            .preferredColorScheme(.light)
    }
}
