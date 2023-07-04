//
//  SettingsUploadErrorView.swift
//  AWattPrice
//
//  Created by Léon Becker on 22.01.21.
//

import Resolver
import SwiftUI

struct SettingsUploadErrorView: View {
    @Injected var notificationSetting: NotificationSettingCoreData
    @Injected var setting: SettingCoreData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.title)
            
            Spacer()
            
            Text("Error uploading settings")
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(.white)
        .padding([.top, .bottom], 8)
        .padding([.leading, .trailing], 16)
        .background(Color.red)
        .cornerRadius(10)
    }
}

struct SettingsUploadErrorView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsUploadErrorView()
            .frame(width: 300)
    }
}
