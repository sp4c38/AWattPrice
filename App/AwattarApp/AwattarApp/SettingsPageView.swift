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

struct SettingsPageView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var pricesWithTaxIncluded = true
    
    @State var awattarEnergyProfileIndex: Int = 0
    @State var basicCharge = ""
    @State var energyPrice = ""
    
    let stringToNumberConverter: NumberFormatter
    
    init() {
        stringToNumberConverter = NumberFormatter()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack {
                Spacer()
                Text("settings")
                    .bold()
                    .font(.largeTitle)
                    
                Spacer()
            }
            .padding(.bottom, 10)
            
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
                        changeTaxSelection(newTaxSelection: newValue, settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("awattarTariff")
                    .bold()
                
                Text("tariffSelectionTip")
                    .font(.caption)
                    .foregroundColor(Color.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)

                VStack(alignment: .center, spacing: 15) {
                    Picker(selection: $awattarEnergyProfileIndex, label: Text("")) {
                        ForEach(awattarData.profilesData.profiles, id: \.name) { profile in
                            Text(profile.name).tag(awattarData.profilesData.profiles.firstIndex(of: profile)!)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: awattarEnergyProfileIndex) { newValue in
                        changeEnergyProfileIndex(newProfileIndex: Int16(newValue), settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                    }

                    VStack {
                        Image(awattarData.profilesData.profiles[awattarEnergyProfileIndex].imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60, alignment: .center)
                            .padding(.top, 5)

                        Text(awattarData.profilesData.profiles[awattarEnergyProfileIndex].name)
                            .bold()
                            .font(.title3)
                            .padding(.bottom, 10)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("basicFee")
                            HStack(spacing: 0) {
                                TextField("", text: $basicCharge)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: basicCharge) { newValue in
                                        let numberConverter = NumberFormatter()
                                        if newValue.contains(",") {
                                            numberConverter.decimalSeparator = ","
                                        } else {
                                            numberConverter.decimalSeparator = "."
                                        }
                                        
                                        changeBasicCharge(newBasicCharge: Float(truncating: numberConverter.number(from: newValue) ?? 0), settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                                    }
                                
                                Text("euroPerMonth")
                                    .padding(.leading, 5)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("elecPriceColon")
                            HStack(spacing: 0) {
                                TextField("", text: $energyPrice)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: energyPrice) { newValue in
                                        let numberConverter = NumberFormatter()
                                        if newValue.contains(",") {
                                            numberConverter.decimalSeparator = ","
                                        } else {
                                            numberConverter.decimalSeparator = "."
                                        }
                                        
                                        changeEnergyCharge(newEnergyCharge: Float(truncating: numberConverter.number(from: newValue) ?? 0), settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                                    }
                                
                                Text("centPerKwh")
                                    .padding(.leading, 5)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.top, 40)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .onAppear {
            pricesWithTaxIncluded = currentSetting.setting!.pricesWithTaxIncluded
            awattarEnergyProfileIndex = Int(currentSetting.setting!.awattarEnergyProfileIndex)
            basicCharge = String(currentSetting.setting!.awattarProfileBasicCharge)
            energyPrice = String(currentSetting.setting!.awattarEnergyPrice)
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting())
    }
}
