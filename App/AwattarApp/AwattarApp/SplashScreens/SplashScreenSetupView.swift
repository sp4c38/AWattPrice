//
//  SplashScreenSetupView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

struct SplashScreenSetupView: View {
    @State var basicCharge: String = ""
    
    var body: some View {
        VStack {
            VStack(spacing: 40) {
                Text("Setup")
                    .font(.system(size: 40, weight: .black))
            
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(Color.red)
                        .font(.system(size: 40))
                    
                    Text("Da die folgenden Preise je nach Region verschieden sind, lesen sie bitte aus aWATTar.de Ihre Gebühren ab. Dies muss nur einmal durchgeführt werden..")
                        .font(.callout)
                }
                
                VStack(alignment: .leading) {
                    Text("basicFee")
                        .font(.headline)
                    
                    TextField("euro per year", text: $basicCharge)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: basicCharge) { newValue in
                            let numberConverter = NumberFormatter()
                            if newValue.contains(",") {
                                numberConverter.decimalSeparator = ","
                            } else {
                                numberConverter.decimalSeparator = "."
                            }
                        
    //                    changeBasicCharge(newBasicCharge: Float(truncating: numberConverter.number(from: newValue) ?? 0), settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("elecPriceColon")
                        .font(.headline)
                    
                    TextField("cent per kWh", text: $basicCharge)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: basicCharge) { newValue in
                            let numberConverter = NumberFormatter()
                            if newValue.contains(",") {
                                numberConverter.decimalSeparator = ","
                            } else {
                                numberConverter.decimalSeparator = "."
                            }
                        
    //                    changeBasicCharge(newBasicCharge: Float(truncating: numberConverter.number(from: newValue) ?? 0), settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                    }
                }
            }
            .padding(.bottom, 20)
            
            Spacer()
            
            Button(action: {}) {
                Text("Continue")
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .padding(.top, 40)
        .padding([.leading, .trailing], 20)
    }
}

struct SplashScreenSetupView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenSetupView()
            .preferredColorScheme(.dark)
    }
}
