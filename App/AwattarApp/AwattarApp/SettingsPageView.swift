//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import SceneKit
import SwiftUI

extension AnyTransition {
    static var switchPlaces: AnyTransition {
        let insertion = AnyTransition.scale(scale: 2).combined(with: .opacity)
        let removal = AnyTransition.move(edge: .bottom).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

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
    
    @State var baseEnergyPrice = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading) {
                Text("elecPriceColon")
                    .font(.headline)

                TextField("centPerKwh", text: $baseEnergyPrice)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: baseEnergyPrice) { newValue in
                        let numberConverter = NumberFormatter()
                        if newValue.contains(",") {
                            numberConverter.decimalSeparator = ","
                        } else {
                            numberConverter.decimalSeparator = "."
                        }
                        
                        currentSetting.changeBaseElectricityCharge(newBaseElectricityCharge: Float(truncating: numberConverter.number(from: newValue) ?? 0))
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
        .onAppear {
            baseEnergyPrice = String(currentSetting.setting!.awattarBaseElectricityPrice)
        }
    }
}

/// A place for the user to modify certain settings. Those changes are automatically stored (if modified) in persistent storage.
struct SettingsPageView: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                PricesWithVatIncludedSetting()
//                AwattarTarifSelectionSetting()
                AwattarBasicEnergyChargePriceSetting()
                
                Spacer()
            }
            .padding(.top, 10)
            .padding([.leading, .trailing], 16)
            .navigationBarTitle("settings")
            .contentShape(Rectangle())
            .onTapGesture {
                self.hideKeyboard()
            }
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
