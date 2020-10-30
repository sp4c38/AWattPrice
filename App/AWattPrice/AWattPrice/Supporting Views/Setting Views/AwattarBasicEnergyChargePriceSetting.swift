//
//  AwattarBasicEnergyChargePriceSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 29.10.20.
//

import SwiftUI

struct AwattarBasicEnergyChargePriceSetting: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var baseEnergyPriceString = ""
    
    struct SettingFooter: View {
        var body: some View {
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
    }
    
    var body: some View {
        Section(
            header: Text("elecPrice"),
            footer: SettingFooter()
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("centPerKwh", text: $baseEnergyPriceString.animation())
                        .keyboardType(.decimalPad)
                        .onChange(of: baseEnergyPriceString) { newValue in
                            currentSetting.changeBaseElectricityCharge(newBaseElectricityCharge: Float( newValue.doubleValue ?? 0))
                        }
                        .padding([.top, .bottom], 5)
                    
                    if baseEnergyPriceString != "" {
                        Text("centPerKwh")
                            .transition(.opacity)
                    }
                }
            }
            .onAppear {
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                numberFormatter.maximumFractionDigits = 2
                
                let baseEnergyPrice = currentSetting.setting!.awattarBaseElectricityPrice
                if baseEnergyPrice == 0 {
                    baseEnergyPriceString = ""
                } else {
                    baseEnergyPriceString = numberFormatter.string(from: NSNumber(value: baseEnergyPrice)) ?? ""
                }
            }
        }
    }
}
