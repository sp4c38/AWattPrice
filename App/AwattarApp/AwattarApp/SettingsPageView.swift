//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

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
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var energyData: EnergyData
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State var pricesWithTaxIncluded = true
    @State var awattarEnergyProfileIndex: Int = 0
    @State var eldo = 0
    
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
                        .padding(.leading, 5)
                    
                    Toggle(isOn: $pricesWithTaxIncluded) {
                        
                    }
                }
                
                Text(pricesWithTaxIncluded ? taxOptions[0] : taxOptions[1])
                    .font(.caption)
                    .foregroundColor(Color.gray)
                    .padding(.leading, 5)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("aWATTar Tarif:")
                    .bold()
                    .padding(.leading, 5)
                
                VStack(alignment: .leading) {                    
                    Text("Wenn du bereits ein aWATTar Kunde bist, kannst du hier deinen Tarif auswählen, um Kosten genauer für dich anzuzeigen.")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .padding(.leading, 5)
                    
                    if energyData.profilesData != nil {
                        Picker(selection: $awattarEnergyProfileIndex, label: Text("aWATTAr Profil Einstellungen")) {
                            ForEach(energyData.profilesData!.profiles, id: \.name) { profile in
                                Text(profile.name).tag(energyData.profilesData!.profiles.firstIndex(of: profile)!)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
            }

            
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
            pricesWithTaxIncluded = currentSetting.setting!.pricesWithTaxIncluded
            awattarEnergyProfileIndex = Int(currentSetting.setting!.awattarEnergyProfileIndex)
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
    }
}
