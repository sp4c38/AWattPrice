//
//  WhatsNewPage.swift
//  AWattPrice
//
//  Created by Léon Becker on 31.12.20.
//

import EffectsLibrary
import Resolver
import SwiftUI

struct WhatsNewPage: View {
    @Environment(\.deviceType) var deviceType
    @Environment(\.presentationMode) var presentationMode

    var fireworkConfig = FireworksConfig(
        content: [
            .emoji("⚡️", 15.0)
        ],
        intensity: .medium,
        lifetime: .long,
        initialVelocity: .fast,
        fadeOut: .medium
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 15) {
                        AppFeatureView(
                            title: "Widgets are here!",
                            subTitle: "whatsNew.widgets.subTitle",
                            tipText: "whatsNew.widgets.tipText",
                            imageName: ("square.text.square", true)
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
                
                FireworksView(config: fireworkConfig)
                    .disabled(true)
            }
        }
    }
}

struct WhatsNewPage_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewPage()
            .environment(\.locale, Locale(identifier: "de"))
    }
}
