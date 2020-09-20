//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import SceneKit
import SwiftUI

struct DoneButtenStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
    }
}

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
    
    var taxOptions = ["Preise auf der Startseite werden mit der Mehrwertsteuer angezeigt.", "Preise auf der Startseite werden ohne der Mehrwertsteuer angezeigt."]
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    HStack {
                        Spacer()
                        Text("Einstellungen")
                            .bold()
                            .font(.largeTitle)
                            
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preiseinstellungen:")
                            .bold()
                        
                        HStack(spacing: 10) {
                            Text("Preise mit Mehrwertsteuer anzeigen")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Toggle(isOn: $pricesWithTaxIncluded) {
                                
                            }
                        }
                        
                        Text(pricesWithTaxIncluded ? taxOptions[0] : taxOptions[1])
                            .font(.caption)
                            .foregroundColor(Color.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if awattarData.profilesData != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("aWATTar Tarif:")
                                .bold()

                            VStack(alignment: .center, spacing: 15) {
                                Text("Wenn du bereits ein aWATTar Kunde bist, kannst du hier deinen Tarif auswählen, um Kosten genauer für dich anzuzeigen.")
                                    .font(.caption)
                                    .foregroundColor(Color.gray)
                                    .fixedSize(horizontal: false, vertical: true)

                                Picker(selection: $awattarEnergyProfileIndex.animation(), label: Text("aWATTAr Tarif Einstellungen")) {
                                    ForEach(awattarData.profilesData!.profiles, id: \.name) { profile in
                                        Text(profile.name).tag(awattarData.profilesData!.profiles.firstIndex(of: profile)!)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .pickerStyle(SegmentedPickerStyle())

                                HStack(spacing: 20) {
                                    VStack {
//                                        if awattarEnergyProfileIndex == 0 {
                                            VStack {
                                                Image("hourlyProfilePicture")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 60, height: 60, alignment: .center)
                                                    .padding(.top, 5)

                                                Text(awattarData.profilesData!.profiles[0].name)
                                                    .font(.title3)
                                                    .bold()
                                                    .padding(.bottom, 10)

                                                VStack(alignment: .leading, spacing: 10) {
                                                    Text("Grundgebühr:")
                                                    HStack(spacing: 0) {
                                                        TextField("", text: $basicCharge)
                                                            .keyboardType(.decimalPad)
                                                        
                                                        Text("Euro pro Monat")
                                                            .padding(.trailing, 5)
                                                    }
                                                    .padding(5)
                                                    .padding(.leading, 5)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(Color.black, lineWidth: 3)
                                                    )
                                                    .shadow(radius: 5)
                                                }

                                                VStack(alignment: .leading, spacing: 10) {
                                                    Text("Arbeitspreis:")
                                                    HStack(spacing: 0) {
                                                        TextField("", text: $energyPrice)
                                                            .keyboardType(.decimalPad)
                                                        
                                                        Text("Cent pro kWh")
                                                            .padding(.trailing, 5)
                                                    }
                                                    .padding(5)
                                                    .padding(.leading, 5)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(Color.black, lineWidth: 3)
                                                    )
                                                    .shadow(radius: 5)
                                                }
                                            }
                                            .transition(.switchPlaces)
//
//                                        } else if awattarEnergyProfileIndex == 1 {
//                                            VStack {
//                                                Image("hourlyCapProfilePicture")
//                                                    .resizable()
//                                                    .scaledToFit()
//                                                    .frame(width: 40, height: 40, alignment: .center)
//
//                                                Text(awattarData.profilesData!.profiles[1].name)
//                                                    .font(.title3)
//                                                    .bold()
//
//                                            }
//                                            .transition(.switchPlaces)

//                                        } else if awattarEnergyProfileIndex == 2 {
//                                            VStack {
//                                                Image("yearlyProfilePicture")
//                                                    .resizable()
//                                                    .scaledToFit()
//                                                    .frame(width: 60, height: 60, alignment: .center)
//
//                                                Text(awattarData.profilesData!.profiles[2].name)
//                                                    .font(.title3)
//                                                    .bold()
//                                            }
//                                            .transition(.switchPlaces)
//                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .padding(.trailing, 5)
            .padding(.top, 5)
            
            Button(action: {
                storeTaxSettingsSelection(
                    pricesWithTaxIncluded: pricesWithTaxIncluded,
                    awattarEnergyProfileIndex: Int16(awattarEnergyProfileIndex),
                    basicCharge: Float(basicCharge) ?? Float(0),
                    energyPrice: Float(energyPrice) ?? Float(0),
                    managedObjectContext: managedObjectContext)
            }) {
               Text("Speichern")
            }
            .buttonStyle(DoneButtenStyle())
            .padding(5)
            
        }
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
