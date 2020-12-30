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
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    @EnvironmentObject var currentSetting: CurrentSetting
    
    var body: some View {
        NavigationView {
            VStack {
                if currentSetting.entity != nil {
                    CustomInsetGroupedList {
                        RegionAndVatSelection()

//                        AwattarTariffSelectionSetting()

                        if crtNotifiSetting.entity != nil {
                            if crtNotifiSetting.entity!.lastApnsToken != nil {
                                GoToNotificationSettingView()
                            }
                        }

                        GetHelpView()

                        AgreementSettingView(agreementIconName: "doc.text",
                                             agreementName: "general.termsOfUse",
                                             agreementLinks: ("https://awattprice.space8.me/terms_of_use/german.html",
                                                              "https://awattprice.space8.me/terms_of_use/english.html"))

                        AgreementSettingView(agreementIconName: "hand.raised",
                                             agreementName: "general.privacyPolicy",
                                             agreementLinks: ("https://awattprice.space8.me/privacy_policy/german.html",
                                                              "https://awattprice.space8.me/privacy_policy/english.html"))

                        VStack(spacing: 20) {
                            NotAffiliatedView(showGrayedOut: true)
                                .padding([.leading, .trailing], 16)

                            AppVersionView()
                        }
                        .padding(.bottom, 15)
                    }
                } else {
                    Text("settingsPage.notLoadedSettings")
                }
            }
            .navigationTitle(Text("settingsPage.settings"))
            .navigationBarTitleDisplayMode(.large)
            .navigationViewStyle(StackNavigationViewStyle())
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
