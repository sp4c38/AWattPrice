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
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var currentSetting: CurrentSetting
    
    var body: some View {
        NavigationView {
            VStack {
                if currentSetting.entity != nil {
                    CustomInsetGroupedList {
                        RegionAndVatSelection()

//                        AwattarTariffSelectionSetting()

                        GoToNotificationSettingView()
                        
                        GetHelpView()
                        
                        AgreementSettingView(agreementIconName: "doc.text",
                                             agreementName: "general.termsOfUse",
                                             agreementLinks: ("https://awattprice.space8.me/terms_of_use/german.html",
                                                              "https://awattprice.space8.me/terms_of_use/english.html"))
                            
                        AgreementSettingView(agreementIconName: "hand.raised",
                                             agreementName: "general.privacyPolicy",
                                             agreementLinks: ("https://awattprice.space8.me/privacy_policy/german.html",
                                                              "https://awattprice.space8.me/privacy_policy/english.html"))

                        NotAffiliatedView(showGrayedOut: true)
                            .padding([.leading, .trailing], 16)
                        
                        AppVersionView()
                    }
                } else {
                    Text("settingsPage.notLoadedSettings")
                }
            }
            .navigationTitle("settingsPage.settings")
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarItems(trailing: DoneNavigationBarItem(presentationMode: presentationMode))
        }
    }
    
    struct DoneNavigationBarItem: View {
        @EnvironmentObject var currentSetting: CurrentSetting
        @Binding var presentationMode: PresentationMode
        
        var body: some View {
            Button(action: {
                self.hideKeyboard()
                currentSetting.validateTariffAndEnergyPriceSet()
                presentationMode.dismiss()
            }) {
                HStack {
                    Text("Done")
                        .bold()
                        .font(.subheadline)
                }
                .foregroundColor(Color.blue)
                .padding(5)
                .padding([.leading, .trailing], 3)
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
