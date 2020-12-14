//
//  PrivacyPolicyView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.12.20.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        CustomInsetGroupedListItem {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                
                Text("privacyPolicy")
                    .font(.subheadline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.gray)
            }
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            .contentShape(Rectangle())
            .onTapGesture {
                openPrivacyPolicyInBrowser()
            }
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
    }
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView()
    }
}
