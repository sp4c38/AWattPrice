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

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading) {
                    Text("elecPriceColon")
                        .font(.headline)

                    TextField("centPerKwh", text: $basicCharge)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: basicCharge) { newValue in
                            let numberConverter = NumberFormatter()
                            if newValue.contains(",") {
                                numberConverter.decimalSeparator = ","
                            } else {
                                numberConverter.decimalSeparator = "."
                            }

//                            changeEnergyCharge(newEnergyCharge: Float(truncating: numberConverter.number(from: newValue) ?? 0), settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("baseElectricityPriceHint")
                    
                    Button(action: {
                        // Let the user visit this website for him/her to get information which depends on the users location
                        // This isn't yet handled directly in the app
                        
                        UIApplication.shared.open(URL(string: "https://www.awattar.de")!)
                    }) {
                        HStack {
                            Text("toAwattarWebsite")
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(Color.blue)
                    }
                }
                .font(.caption)
                .foregroundColor(Color.gray)
            }

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
