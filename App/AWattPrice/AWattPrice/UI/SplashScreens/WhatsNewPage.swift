//
//  WhatsNewPage.swift
//  AWattPrice
//
//  Created by Léon Becker on 31.12.20.
//

import Resolver
import SwiftUI

struct WhatsNewPage: View {
    @Environment(\.deviceType) var deviceType
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 15) {
                    AppFeatureView(
                        title: "Base Fee",
                        subTitle: "baseFee.infoText",
                        tipText: "splashScreen.whatsNew.baseFee.extrainfo",
                        imageName: ("eurosign.circle", true)
                    )
                }
                .padding(.trailing, 14)

                Spacer()

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("Done")
                })
                    .buttonStyle(ContinueButtonStyle())
                    .padding(.bottom, 10)
            }
            .padding([.leading, .trailing], 16)
            .padding(.top, 25)
            .navigationTitle("What's new?")
        }
    }
}

struct WhatsNewPage_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewPage()
            .environment(\.locale, Locale(identifier: "de"))
    }
}
