//
//  AgreementSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.12.20.
//

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
                    .font(.title2)
                
                Text(agreementName.localized())
                    .font(.subheadline)
                
                Spacer()
                
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

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        AgreementSettingView(agreementIconName: "hand.raised.fill",
                             agreementName: "privacyPolicy",
                             agreementLinks: ("https://awattprice.space8.me/privacy_policy/german.html",
                                              "https://awattprice.space8.me/privacy_policy/english.html"))
    }
}
