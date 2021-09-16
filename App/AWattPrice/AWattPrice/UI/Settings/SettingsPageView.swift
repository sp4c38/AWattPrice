//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import Resolver
import SceneKit
import SwiftUI

/// A place for the user to modify certain settings.
struct SettingsPageView: View {
    @ObservedObject var crtNotifiSetting: CurrentNotificationSetting = Resolver.resolve()
    @ObservedObject var currentSetting: CurrentSetting = Resolver.resolve()
    @ObservedObject var notificationService: NotificationService = Resolver.resolve()
    
    var body: some View {
        NavigationView {
            VStack {
                if currentSetting.entity != nil {
                    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                        CustomInsetGroupedList {
                            RegionAndVatSelection()

    //                        AwattarTariffSelectionSetting()

                            if crtNotifiSetting.entity != nil {
                                GoToNotificationSettingView()
                            }

                            GetHelpView()

                            AgreementSettingView(agreementIconName: "doc.text",
                                                 agreementName: "general.termsOfUse",
                                                 agreementLinks: ("https://awattprice.space8.me/terms_of_use/german.html",
                                                                  "https://awattprice.space8.me/terms_of_use/english.html"))

                            AgreementSettingView(agreementIconName: "hand.raised",
                                                 agreementName: "general.privacyPolicy",
                                                 agreementLinks:
                                                 ("https://awattprice.space8.me/privacy_policy/german.html",
                                                  "https://awattprice.space8.me/privacy_policy/english.html"))

                            VStack(spacing: 20) {
                                NotAffiliatedView(showGrayedOut: true)
                                    .padding([.leading, .trailing], 16)

                                AppVersionView()
                            }
                            .padding(.bottom, 15)
                        }
                        
                        VStack {
                            if case .failure(_) = notificationService.stateLastUpload {
                                SettingsUploadErrorView()
                                    .padding(.bottom, 15)
                            }
                        }
                        .animation(.easeInOut)
                    }
                } else {
                    Text("settingsPage.notLoadedSettings")
                }
            }
            .navigationTitle(Text("settingsPage.settings"))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(
                CurrentSetting(
                    managedObjectContext: PersistenceManager().persistentContainer.viewContext
                )
            )
    }
}
