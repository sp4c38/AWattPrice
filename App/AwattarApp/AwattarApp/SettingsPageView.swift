//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import SceneKit
import SwiftUI

/// A place for the user to modify certain settings. Those changes are automatically stored (if modified) in persistent storage.
struct SettingsPageView: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .center, spacing: 20) {
                PricesWithVatIncludedSetting()
//                AwattarTarifSelectionSetting()
                AwattarBasicEnergyChargePriceSetting()
                
                Spacer()
                
                AppVersionView()
            }
            .padding(.bottom, 20)
            .padding(.top, 15)
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
