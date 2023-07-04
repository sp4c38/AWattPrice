//
//  DataDownloadAndError.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import Resolver
import SwiftUI

struct DataRetrievalLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView("Loading")

            Spacer()
        }
    }
}

struct DataRetrievalError: View {
    @Environment(\.colorScheme) var colorScheme

    @Injected var energyDataController: EnergyDataController
    @Injected var setting: SettingCoreData

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(Color.orange)
                    .font(.system(size: 60, weight: .light))

                Text("Please try again later")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                Button(action: {
                    if let region = Region.init(rawValue: setting.entity.regionIdentifier) {
                        energyDataController.download(region: region)
                    }
                }) {
                    Text("Retry")
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

    @Injected var energyDataController: EnergyDataController
    @Injected var setting: SettingCoreData

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            VStack(spacing: 30) {
                Image(systemName: "rectangle.slash.fill")
                    .foregroundColor(Color(red: 0.99, green: 0.74, blue: 0.04, opacity: 1.0))
                    .font(.system(size: 60, weight: .light))

                Text("No data available\nPlease try again later")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                Button(action: {
                    if let region = Region(rawValue: setting.entity.regionIdentifier) {
                        energyDataController.download(region: region)
                    }
                }) {
                    Text("Retry")
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
    @ObservedObject var energyDataController: EnergyDataController = Resolver.resolve()
    @ObservedObject var notificationSetting: NotificationSettingCoreData = Resolver.resolve()
    @ObservedObject var setting: SettingCoreData = Resolver.resolve()

    var body: some View {
        VStack {
            if case .downloading = energyDataController.downloadState  {
                DataRetrievalLoadingView()
            } else if case .failed = energyDataController.downloadState {
                DataRetrievalError()
            } else if let energyData = energyDataController.energyData, energyData.currentPrices.isEmpty == true {
                CurrentlyNoData()
                    .transition(.opacity)
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
