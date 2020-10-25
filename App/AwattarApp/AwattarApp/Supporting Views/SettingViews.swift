//
//  SettingInputViews.swift
//  AwattarApp
//
//  Created by Léon Becker on 25.10.20.
//

import SwiftUI

struct PricesWithVatIncludedSetting: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var pricesWithTaxIncluded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("price")
                .bold()
            
            HStack(spacing: 10) {
                Text("pricesWithVat")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                
                Toggle(isOn: $pricesWithTaxIncluded) {
                    
                }
                .onChange(of: pricesWithTaxIncluded) { newValue in
                    currentSetting.changeTaxSelection(newTaxSelection: newValue)
                }
            }
        }
        .onAppear {
            pricesWithTaxIncluded = currentSetting.setting!.pricesWithTaxIncluded
        }
    }
}

struct AwattarTarifSelectionSetting: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    
    @State var awattarEnergyProfileIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("awattarTariff")
                .bold()
            
            Text("tariffSelectionTip")
                .font(.caption)
                .foregroundColor(Color.gray)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            Picker(selection: $awattarEnergyProfileIndex, label: Text("")) {
                ForEach(awattarData.profilesData.profiles, id: \.name) { profile in
                    Text(profile.name).tag(awattarData.profilesData.profiles.firstIndex(of: profile)!)
                }
            }
            .frame(maxWidth: .infinity)
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: awattarEnergyProfileIndex) { newValue in
            }

            VStack(alignment: .center, spacing: 15) {
                Image(awattarData.profilesData.profiles[awattarEnergyProfileIndex].imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60, alignment: .center)
                    .padding(.top, 5)
                
                Text(awattarData.profilesData.profiles[awattarEnergyProfileIndex].name)
                    .bold()
                    .font(.title3)
                    .padding(.bottom, 10)
            }
        }
        .onAppear {
            awattarEnergyProfileIndex = Int(currentSetting.setting!.awattarProfileIndex)
        }
    }
}

struct AwattarBasicEnergyChargePriceSetting: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var baseEnergyPriceString = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading) {
                Text("elecPriceColon")
                    .font(.headline)
                
                HStack {
                    TextField("centPerKwh", text: $baseEnergyPriceString.animation())
                        .keyboardType(.decimalPad)
                        .onChange(of: baseEnergyPriceString) { newValue in
                            let numberConverter = NumberFormatter()

                            if newValue.contains(",") {
                                numberConverter.decimalSeparator = ","
                            } else {
                                numberConverter.decimalSeparator = "."
                            }
                            
                            currentSetting.changeBaseElectricityCharge(newBaseElectricityCharge: Float(truncating: numberConverter.number(from: newValue) ?? 0))
                        }
                    
                    if baseEnergyPriceString != "" {
                        Text("Cent")
                            .transition(.opacity)
                    }
                }
                .padding(.leading, 17)
                .padding(.trailing, 14)
                .padding([.top, .bottom], 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706), lineWidth: 2)
                )
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

struct AppVersionView: View {
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            
            Image("SmallAppIcon")
                .resizable()
                .frame(width: 70, height: 70)
                .saturation(0)
                .opacity(0.6)
            
            VStack(spacing: 2) {
                Text("AWattPrice")
                    .font(.headline)
                
                if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                    if let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                        Text("Version \(currentVersion) (\(currentBuild))")
                            .font(.footnote)
                    }
                }
            }
        }
        .foregroundColor(Color(hue: 0.6667, saturation: 0.0448, brightness: 0.5255))
    }
}

struct SettingViews_Previews: PreviewProvider {
    static var previews: some View {
        AppVersionView()
            
    }
}
