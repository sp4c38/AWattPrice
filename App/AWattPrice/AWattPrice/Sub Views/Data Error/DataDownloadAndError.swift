//
//  DataDownloadAndError.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

struct DataRetrievalLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView("general.loading")

            Spacer()
        }
    }
}

struct DataRetrievalError: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.networkManager) var networkManager
    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var currentSetting: CurrentSetting

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(Color.orange)
                    .font(.system(size: 60, weight: .light))

                Text("dataError.download.tryAgainLater")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                Button(action: {
                    backendComm.download(forRegion: currentSetting.entity!.regionIdentifier, networkManager: networkManager)
                }) {
                    Text("general.retry")
                }.buttonStyle(RetryButtonStyle())
            }
            .padding(25)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme == .light ? Color(hue: 0.0000, saturation: 0.0000, brightness: 0.9137) : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.2446), lineWidth: 5)
            )

            Spacer()
        }
    }
}

struct CurrentlyNoData: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.networkManager) var networkManager
    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var currentSetting: CurrentSetting

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            VStack(spacing: 30) {
                Image(systemName: "rectangle.slash.fill")
                    .foregroundColor(Color(red: 0.99, green: 0.74, blue: 0.04, opacity: 1.0))
                    .font(.system(size: 60, weight: .light))

                Text("dataError.download.noDataAvailable")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                Button(action: {
                    backendComm.download(forRegion: currentSetting.entity!.regionIdentifier, networkManager: networkManager)
                }) {
                    Text("general.retry")
                }.buttonStyle(RetryButtonStyle())
            }
            .padding(25)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme == .light ? Color(hue: 0.0000, saturation: 0.0000, brightness: 0.9137) : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.2446), lineWidth: 5)
            )

            Spacer()
        }
    }
}

struct SettingLoadingError: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            VStack(spacing: 30) {
                Image(systemName: "gear")
                    .foregroundColor(Color.red)
                    .font(.system(size: 60, weight: .light))

                Text("dataError.settings.settingsLoadingError")
                    .foregroundColor(Color.red)
                    .font(.title3)
                    .multilineTextAlignment(.center)
            }
            .padding(25)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red, lineWidth: 5)
            )

            Spacer()
        }
    }
}

/// Classify network errors
struct DataDownloadAndError: View {
    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    @EnvironmentObject var currentSetting: CurrentSetting

    var body: some View {
        VStack {
            if crtNotifiSetting.entity == nil || currentSetting.entity == nil {
                SettingLoadingError()
            } else if backendComm.dataRetrievalError == true {
                DataRetrievalError()
                    .transition(.opacity)
            } else if backendComm.currentlyNoData == true {
                CurrentlyNoData()
                    .transition(.opacity)
            } else if backendComm.currentlyUpdatingData == true {
                DataRetrievalLoadingView()
            }
        }
        .padding()
    }
}

struct NetworkConnectionErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DataRetrievalError()
                .preferredColorScheme(.dark)
            CurrentlyNoData()
                .preferredColorScheme(.dark)
            SettingLoadingError()
                .preferredColorScheme(.dark)
        }
    }
}
