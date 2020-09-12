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
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var settingsOptions: SettingsOptions
    
    var taxOptions = [(0, "Mit Mehrwertsteuer", "Preise auf der Startseite werden mit der Mehrwertsteuer angezeigt."), (1, "Ohne Mehrwertsteuer", "Preise auf der Startseite werden ohne der Mehrwertsteuer angezeigt.")]

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            HStack {
                Spacer()
                Text("Einstellungen")
                    .bold()
                    .font(.largeTitle)
                Spacer()
            }
            
            VStack(alignment: .leading) {
                Text("Preiseinstellungen:")
                    .padding(.leading, 5)
                
                VStack(alignment: .leading, spacing: 10) {
                    Picker(selection: $settingsOptions.selectedTaxOption, label: Text("Picker")) {
                        ForEach(taxOptions, id: \.0) { taxOption in
                            Text(taxOption.1).tag(taxOption.0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .pickerStyle(SegmentedPickerStyle())

                    Text(taxOptions[Int(settingsOptions.selectedTaxOption)].2)
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .padding(.leading, 5)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("aWATTar Tarif:")
                    .padding(.leading, 5)
                
                VStack(alignment: .leading) {
    //                Picker(selection: $selectedTaxOption, label: Text("Picker")) {
    //                    ForEach(taxOptions, id: \.0) { taxOption in
    //                        Text(taxOption.1).tag(taxOption.0)
    //                    }
    //                }
    //                .frame(maxWidth: .infinity)
    //                .pickerStyle(SegmentedPickerStyle())
                    
                    Text("Wenn du bereits ein aWATTar Kunde bist, kannst du hier deinen Tarif auswählen, um extra Infos für genau deinen Tarif zu sehen.")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .padding(.leading, 5)
                }
            }

            
            Spacer()
            Button(action: {
                storeTaxSettingsSelection(
                    selectedTaxSetting: Int16(settingsOptions.selectedTaxOption),
                    managedObjectContext: managedObjectContext)
            }) {
               Text("Speichern")
            }.buttonStyle(DoneButtenStyle())
        }
        .padding(20)
        .onAppear {
            settingsOptions.selectedTaxOption = getTaxSettingsSelection(managedObjectContext: managedObjectContext)
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
    }
}
