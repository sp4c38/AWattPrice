//
//  WhatsNewPage.swift
//  AWattPrice
//
//  Created by Léon Becker on 31.12.20.
//

import SwiftUI

struct WhatsNewPage: View {
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var currentSetting: CurrentSetting
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 15) {
                    AppFeatureView(title: "notificationPage.notifications", subTitle: "splashScreen.featuresAndConsent.notifications.info", tipText: "splashScreen.whatsNew.notifications.extrainfo", imageName: "app.badge")
                }
                
                Spacer()
                
                Button(action: {
                    currentSetting.changeShowWhatsNew(newValue: false)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("general.continue")
                }
                .buttonStyle(ContinueButtonStyle())
            }
            .padding(.top, 25)
            .padding([.leading, .trailing], 16)
            .navigationTitle("splashScreen.whatsNew.title")
        }
    }
}

struct WhatsNewPage_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewPage()
    }
}
