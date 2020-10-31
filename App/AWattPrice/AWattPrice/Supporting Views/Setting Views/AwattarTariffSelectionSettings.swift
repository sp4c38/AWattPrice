//
//  AwattarTariffSelectionSettings.swift
//  AWattPrice
//
//  Created by Léon Becker on 29.10.20.
//

import SwiftUI

struct AwattarBasicEnergyChargePriceSetting: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var baseEnergyPriceString = ""
    
    @Binding var textFieldCurrentlySelected: Bool
    
    struct SettingFooter: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                TextField("centPerKwh",
                          text: $baseEnergyPriceString.animation(),
                          onEditingChanged: { value in
                              textFieldCurrentlySelected = value
                          })
                    .keyboardType(.decimalPad)
                    .onChange(of: baseEnergyPriceString) { newValue in
                        currentSetting.changeBaseElectricityCharge(newBaseElectricityCharge: Float( newValue.doubleValue ?? 0))
                    }
                
                
                if baseEnergyPriceString != "" {
                    Text("centPerKwh")
                        .transition(.opacity)
                }
            }
            .padding([.top, .bottom], 7)
            .padding([.leading, [.trailing]], 10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hue: 0.6667, saturation: 0.0202, brightness: 0.8686), lineWidth: 2))
            
            SettingFooter()
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


struct AwattarTariffSelectionSetting: View {
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var awattarEnergyTariffIndex: Int = 0
    
    @Binding var textFieldCurrentlySelected: Bool
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text("awattarTariff"),
            footer: Text("awattarTariffSelectionTip")
        ) {
            VStack(alignment: .center, spacing: 20) {
                Picker(selection: $awattarEnergyTariffIndex.animation(), label: Text("")) {
                    Text("none").tag(-1)
                    ForEach(awattarData.profilesData.profiles, id: \.name) { profile in
                        Text(profile.name).tag(awattarData.profilesData.profiles.firstIndex(of: profile)!)
                    }
                }
//                .allowsHitTesting(false)
                .onChange(of: awattarEnergyTariffIndex) { newValue in
                }
                .frame(maxWidth: .infinity)
                .pickerStyle(SegmentedPickerStyle())

                if awattarEnergyTariffIndex != -1 {
                    VStack(alignment: .center, spacing: 25) {
                        VStack(alignment: .center, spacing: 15) {
                            Image(awattarData.profilesData.profiles[awattarEnergyTariffIndex].imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60, alignment: .center)
                                .padding(.top, 5)

                            Text(awattarData.profilesData.profiles[awattarEnergyTariffIndex].name)
                                .bold()
                                .font(.title3)
                        }
                    
                        AwattarBasicEnergyChargePriceSetting(textFieldCurrentlySelected: $textFieldCurrentlySelected)
                    }
                } else {
                    VStack(alignment: .center, spacing: 15) {
                        Image(systemName: "multiply.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60, alignment: .center)
                            .padding(.top, 5)
                            .foregroundColor(Color.orange)

                        Text("none")
                            .bold()
                            .font(.title3)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 10)
            .onAppear {
                awattarEnergyTariffIndex = 0//Int(currentSetting.setting!.awattarTariffIndex)
            }
        }
    }
}

struct AwattarTarifSelectionSettings_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AwattarTariffSelectionSetting(textFieldCurrentlySelected: .constant(false))
                .environmentObject(AwattarData())
                .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
        }
    }
}
