//
//  AwattarTariffSelectionSettings.swift
//  AWattPrice
//
//  Created by Léon Becker on 29.10.20.
//

import SwiftUI

struct AwattarTarifSelectionSetting: View {
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var awattarEnergyTariffIndex: Int = 0
    
    var body: some View {
        Section(
            header: Text("awattarTariff"),
            footer: Text("awattarTariffSelectionTip")
        ) {
            VStack(alignment: .center, spacing: 10) {
                Picker(selection: $awattarEnergyTariffIndex, label: Text("")) {
                    Text("none").tag(-1)
                    ForEach(awattarData.profilesData.profiles, id: \.name) { profile in
                        Text(profile.name).tag(awattarData.profilesData.profiles.firstIndex(of: profile)!)
                    }
                }
                .onChange(of: awattarEnergyTariffIndex) { newValue in
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .pickerStyle(SegmentedPickerStyle())
                .zIndex(0)

                if awattarEnergyTariffIndex != -1 {
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
                } else {
                    VStack(alignment: .center, spacing: 15) {
                        Image(systemName: "multiply.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60, alignment: .center)
                            .padding(.top, 5)

                        Text("none")
                            .bold()
                            .font(.title3)
                    }
                }
            }
            .animation(.easeInOut)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .onAppear {
            awattarEnergyTariffIndex = Int(currentSetting.setting!.awattarTariffIndex)
        }
    }
}

struct AwattarTarifSelectionSettings_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                AwattarTarifSelectionSetting()
                    .environmentObject(AwattarData())
                    .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
            }.listStyle(InsetGroupedListStyle())
        }
    }
}
