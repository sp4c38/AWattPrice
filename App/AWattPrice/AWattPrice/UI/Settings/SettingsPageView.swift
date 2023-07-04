//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import Resolver
import SceneKit
import SwiftUI

struct GoToBaseFeeSettingsView: View {
    var body: some View {
        NavigationLink(destination: BaseFeeView()) {
            Image(systemName: "eurosign.circle")
                .resizable()
                .frame(width: 22, height: 22)
            
            Text("Base Fee")
                .bold()
        }
    }
}

struct GoToNotificationSettingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            NavigationLink(destination: NotificationSettingView()) {
                Image("PriceTag")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 22, height: 22)
                
                Text("Price Guard")
                    .bold()
            }
            
            Text("notificationPage.notification.priceDropsBelowValue.description")
                .font(.subheadline)
        }
    }
}

struct GetHelpView: View {
    var body: some View {
        NavigationLink(destination: LazyNavigationDestination(HelpAndSuggestionView())) {
            Image(systemName: "questionmark.circle")
                .resizable()
                .frame(width: 22, height: 22, alignment: .center)
            
            Text("Help & Suggestions")
                .font(.subheadline)
        }
    }
}

struct AgreementSettingView: View {
    enum AgreementType {
        case termsOfUse, privacyPolicy
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    var agreementType: AgreementType
    
    var agreementIconName: String
    var agreementName: String
    var agreementLinks: (String, String)
    
    init(agreementType: AgreementType) {
        self.agreementType = agreementType
        
        switch agreementType {
        case .termsOfUse:
            agreementIconName = "doc.text"
            agreementName = "Terms Of Use"
            agreementLinks = ("https://awattprice.space8.me/terms_of_use/german.html",
                              "https://awattprice.space8.me/terms_of_use/english.html")
        case .privacyPolicy:
            agreementIconName = "hand.raised"
            agreementName = "Privacy Policy"
            agreementLinks = ("https://awattprice.space8.me/privacy_policy/german.html",
                              "https://awattprice.space8.me/privacy_policy/english.html")
        }
        
    }
    
    var body: some View {
        NavigationLink(destination: EmptyView(), isActive: .constant(false)) {
            Image(systemName: agreementIconName)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
            
            Text(agreementName.localized())
                .font(.subheadline)
        }
        .onTapGesture {
            openAgreementLink(agreementLinks)
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

                if let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                    Text("\("Version".localized()) \(AppContext.shared.currentAppVersion) (\(currentBuild))")
                        .font(.footnote)
                }
            }
            Spacer()
        }
        .foregroundColor(Color(hue: 0.6667, saturation: 0.0448, brightness: 0.5255))
    }
}


struct SettingsPageView: View {
    @ObservedObject var notificationSetting: NotificationSettingCoreData = Resolver.resolve()
    @ObservedObject var setting: SettingCoreData = Resolver.resolve()
    var notificationService: NotificationService = Resolver.resolve()
    
    let regionTaxSelectionViewModel = RegionTaxSelectionViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Region"), footer: Text("settingsPage.regionToGetPrices")) {
                    RegionTaxSelectionView(viewModel: regionTaxSelectionViewModel)
                }

                Section {
                    GoToBaseFeeSettingsView()
                }
                
                Section {
                    GoToNotificationSettingView()
                }
                    
                Section {
                    GetHelpView()
                    AgreementSettingView(agreementType: .termsOfUse)
                    AgreementSettingView(agreementType: .privacyPolicy)
                }

                VStack(spacing: 20) {
                    NotAffiliatedView(showGrayedOut: true)
                    AppVersionView()
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(Text("Settings"))
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
            .environment(\.managedObjectContext, getCoreDataContainer().viewContext)
            .environmentObject(
                SettingCoreData(
                    viewContext: getCoreDataContainer().viewContext
                )
            )
    }
}
