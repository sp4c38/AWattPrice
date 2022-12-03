//
//  SettingsUploadErrorView.swift
//  AWattPrice
//
//  Created by Léon Becker on 22.01.21.
//

import Resolver
import SwiftUI

struct SettingsUploadErrorView: View {
    @Injected var crtNotifiSetting: CurrentNotificationSetting
    @Injected var currentSetting: CurrentSetting

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle")
                .font(.title)

            Text("Error uploading settings")
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.red)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct SettingsUploadErrorView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsUploadErrorView()
    }
}
