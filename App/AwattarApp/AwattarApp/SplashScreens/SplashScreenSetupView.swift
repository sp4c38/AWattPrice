//
//  SplashScreenSetupView.swift
//
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

/// Splash screen which handles the input of settings which are required for the main functionality of the app.
struct SplashScreenSetupView: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var redirectToNextSplashScreen: Int? = 0
    @State var basicCharge: String = ""
    
    var body: some View {
        VStack(spacing: 40) {
            Text("splashScreenSetupTitle")
                .font(.system(size: 40, weight: .black))

            AwattarBasicEnergyChargePriceSetting()

            Spacer()
            Spacer()

            NavigationLink("", destination: SplashScreenFinishView(), tag: 1, selection: $redirectToNextSplashScreen)
            
            Button(action: {
                redirectToNextSplashScreen = 1
            }) {
                Text("splashScreenContinueButton")
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .navigationBarHidden(true)
        .padding(.top, 40)
        .padding([.leading, .trailing], 20)
        .padding(.bottom, 16)
    }
}

struct SplashScreenSetupView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenSetupView()
            .preferredColorScheme(.light)
    }
}
