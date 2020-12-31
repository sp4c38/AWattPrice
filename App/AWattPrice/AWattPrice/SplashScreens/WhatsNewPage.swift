//
//  WhatsNewPage.swift
//  AWattPrice
//
//  Created by Léon Becker on 31.12.20.
//

import SwiftUI

struct WhatsNewPage: View {
    var body: some View {
        NavigationView {
            VStack {
                AppFeatureView(title: "Notifications", subTitle: "You can now enable receiving a push notification if prices drop below a custom set value.", imageName: "app.badge")
            }
            .navigationTitle("What's new!")
            .toolbar {
                
            }
        }
    }
}

struct WhatsNewPage_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewPage()
    }
}
