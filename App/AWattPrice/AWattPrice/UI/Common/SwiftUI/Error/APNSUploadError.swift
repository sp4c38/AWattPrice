//
//  APNSUploadError.swift
//  AWattPrice
//
//  Created by Léon Becker on 22.01.21.
//

import SwiftUI

struct APNSUploadError: View {
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    @EnvironmentObject var currentSetting: CurrentSetting

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .font(.title)

                Text("dataError.apns.errorUploading")
            }

//            Button(action: {
//                crtNotifiSetting.pushNotificationUpdateManager.backgroundNotificationUpdate(
//                    currentSetting, crtNotifiSetting
//                )
//            }) {
//                Text("general.retry")
//                    .bold()
//                    .padding(5)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 5)
//                            .stroke(Color.white, lineWidth: 2)
//                    )
//                    .background(
//                        Color.red
//                            .cornerRadius(5)
//                            .shadow(radius: 5)
//                    )
//            }
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.red)
        .cornerRadius(10)
        .shadow(radius: 5)
        .onAppear { playErrorHapticFeedback() }
        .onDisappear { playSuccessHapticFeedback() }
    }
}

struct APNSUploadError_Previews: PreviewProvider {
    static var previews: some View {
        APNSUploadError()
    }
}
