//
//  WhatsNewPage.swift
//  AWattPrice
//
//  Created by Léon Becker on 31.12.20.
//

import SwiftUI

struct WhatsNewPage: View {
    @Environment(\.deviceType) var deviceType
    @Environment(\.presentationMode) var presentationMode

    @EnvironmentObject var currentSetting: CurrentSetting

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 15) {
                    AppFeatureView(
                        title: "general.priceGuard",
                        subTitle: "notificationPage.notification.priceDropsBelowValue.description",
                        tipText: "splashScreen.whatsNew.notifications.extrainfo",
                        imageName: ("PriceTag", false)
                    )
                }
                .padding(.trailing, 14)

                if deviceType == .phone {
                    Spacer()
                }

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("general.done")
                })
                    .buttonStyle(ContinueButtonStyle())
                    .padding(.bottom, 10)
            }
            .padding([.leading, .trailing], 16)
            .padding(.top, 25)
            .navigationTitle("splashScreen.whatsNew.title")
        }
    }
}

struct WhatsNewPage_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewPage()
    }
}
