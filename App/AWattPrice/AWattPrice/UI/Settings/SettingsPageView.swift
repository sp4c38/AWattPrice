//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import Resolver
import SceneKit
import SwiftUI

struct AgreementSettingView: View {
    @Environment(\.colorScheme) var colorScheme

    var agreementIconName: String
    var agreementName: String
    var agreementLinks: (String, String)

    var body: some View {
        CustomInsetGroupedListItem {
            HStack {
                Image(systemName: agreementIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22, alignment: .center)

                Text(agreementName.localized())
                    .font(.subheadline)

                Spacer(minLength: 3)

                Image(systemName: "chevron.right")
                    .font(Font.caption.weight(.semibold))
                    .foregroundColor(Color.gray)
            }
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            .contentShape(Rectangle())
            .onTapGesture {
                openAgreementLink(agreementLinks)
            }
        }
    }
}

struct NotAffiliatedView: View {
    let setFixedSize: Bool
    let showGrayedOut: Bool

    init(setFixedSize: Bool = false, showGrayedOut: Bool) {
        self.setFixedSize = setFixedSize
        self.showGrayedOut = showGrayedOut
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.fSubHeadline)
                .foregroundColor(Color.blue)

            Text("splashScreen.start.notAffiliatedNote")
                .font(setFixedSize ? .fSubHeadline : .subheadline)
                .ifTrue(showGrayedOut == true) { content in
                    content
                        .foregroundColor(Color.gray)
                }
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AppVersionView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Image("BigAppIcon")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .saturation(0)
                    .opacity(0.6)

                Text("AWattPrice")
                    .font(.headline)

                if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                    if let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                        Text("\("settingsPage.version".localized()) \(currentVersion) (\(currentBuild))")
                            .font(.footnote)
                    }
                }
            }
            Spacer()
        }
        .foregroundColor(Color(hue: 0.6667, saturation: 0.0448, brightness: 0.5255))
    }
}


/// A place for the user to modify certain settings.
struct SettingsPageView: View {
    @ObservedObject var crtNotifiSetting: CurrentNotificationSetting = Resolver.resolve()
    @ObservedObject var currentSetting: CurrentSetting = Resolver.resolve()
    var notificationService: NotificationService = Resolver.resolve()
    
    let regionTaxSelectionViewModel = RegionTaxSelectionViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if currentSetting.entity != nil {
                    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                        CustomInsetGroupedList {
                            RegionTaxSelectionView(viewModel: regionTaxSelectionViewModel)

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
//                            if case .failure(_) = notificationService.stateLastUpload {
//                                SettingsUploadErrorView()
//                                    .padding(.bottom, 15)
//                            }
                        }
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
