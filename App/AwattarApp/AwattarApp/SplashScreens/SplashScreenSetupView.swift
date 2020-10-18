//
//  SplashScreenSetupView.swift
//
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

struct SplashScreenSetupView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var redirectToNextSplashScreen: Int? = 0
    @State var basicCharge: String = ""
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Setup")
                .font(.system(size: 40, weight: .regular))

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading) {
                    Text("elecPriceColon")
                        .font(.headline)

                    TextField("Cent per kWh", text: $basicCharge)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: basicCharge) { newValue in
                            let numberConverter = NumberFormatter()
                            if newValue.contains(",") {
                                numberConverter.decimalSeparator = ","
                            } else {
                                numberConverter.decimalSeparator = "."
                            }

                            changeEnergyCharge(newEnergyCharge: Float(truncating: numberConverter.number(from: newValue) ?? 0), settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                    }
                    }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sie können Ihren Arbeitspreis für Ihre Region auf der aWATTar Webseite finden.")
                    
                    Button(action: {
                        UIApplication.shared.open(URL(string: "https://www.awattar.de")!)
                    }) {
                        HStack {
                            Text("Zur aWATTar Webseite")
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
                Text("Continue")
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .navigationBarTitleDisplayMode(.large)
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
