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

struct SettingsPageView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var energyData: EnergyData
    
    @State var pricesWithTaxIncluded = true
    @State var awattarEnergyProfileIndex: Int = 0
    
    var taxOptions = ["Preise auf der Startseite werden mit der Mehrwertsteuer angezeigt.", "Preise auf der Startseite werden ohne der Mehrwertsteuer angezeigt."]
    
    var body: some View {
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
                    .padding(.leading, 5)
                
                HStack(spacing: 10) {
                    Text("Preise mit Mehrwertsteuer anzeigen")
                        .font(.caption)
                    
                    Toggle(isOn: $pricesWithTaxIncluded) {
                        
                    }
                }
                
                Text(pricesWithTaxIncluded ? taxOptions[0] : taxOptions[1])
                    .font(.caption)
                    .foregroundColor(Color.gray)
            }
            
//            if energyData.profilesData != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("aWATTar Tarif:")
                        .bold()
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Wenn du bereits ein aWATTar Kunde bist, kannst du hier deinen Tarif auswählen, um Kosten genauer für dich anzuzeigen.")
                            .font(.caption)
                            .foregroundColor(Color.gray)
                        
//                        Picker(selection: $awattarEnergyProfileIndex, label: Text("aWATTAr Profil Einstellungen")) {
//                            ForEach(energyData.profilesData!.profiles, id: \.name) { profile in
//                                Text(profile.name).tag(energyData.profilesData!.profiles.firstIndex(of: profile)!)
//                            }
//                        }
//                        .frame(maxWidth: .infinity)
//                        .pickerStyle(SegmentedPickerStyle())
                        
                        HStack(spacing: 5) {
                            VStack {
                                if awattarEnergyProfileIndex == 0 {
                                    Text("HOURLY")//energyData.profilesData!.profiles[0].name)
                                        .font(.title3)
                                        .bold()
                                } else {
                                    Text(energyData.profilesData!.profiles[0].name)
                                        .font(.title3)
                                }
                            }
                            
                            Spacer()
                            
                            VStack {
                                if awattarEnergyProfileIndex == 1 {
                                    Text(energyData.profilesData!.profiles[1].name)
                                        .font(.title3)
                                        .bold()
                                } else {
                                    Text("HOURLY-CAP")//energyData.profilesData!.profiles[1].name)
                                        .font(.title3)
                                }
                            }
                            
                            Spacer()
                            
                            VStack {
                                if awattarEnergyProfileIndex == 2 {
                                    Text(energyData.profilesData!.profiles[2].name)
                                        .font(.title3)
                                        .bold()
                                } else {
                                    Text("YEARLY")//energyData.profilesData!.profiles[2].name)
                                        .font(.title3)
                                }
                            }
                        }
                        
                        HStack(spacing: 5) {
                            Image("hourlyProfilePicture")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50, alignment: .center)
                            
                            Spacer()
                            
                            Image("yearlyProfilePicture")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50, alignment: .center)
                            
                            Spacer()
                            
                            Image("hourlyCapProfilePicture")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50, alignment: .center)
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 10)
                    }
                }
//            }

            
            Spacer()
            Button(action: {
                storeTaxSettingsSelection(
                    pricesWithTaxIncluded: pricesWithTaxIncluded,
                    awattarEnergyProfileIndex: Int16(awattarEnergyProfileIndex),
                    managedObjectContext: managedObjectContext)
            }) {
               Text("Speichern")
            }.buttonStyle(DoneButtenStyle())
        }
        .padding(20)
        .onAppear {
//            pricesWithTaxIncluded = currentSetting.setting!.pricesWithTaxIncluded
//            awattarEnergyProfileIndex = Int(currentSetting.setting!.awattarEnergyProfileIndex)
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(CurrentSetting())
            .environmentObject(EnergyData())
    }
}
