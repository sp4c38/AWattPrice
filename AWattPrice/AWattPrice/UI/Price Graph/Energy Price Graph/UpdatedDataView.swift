//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import Combine
import SwiftUI

/// Simillar to the built in RelativeDateTimeFormatter but fitted to the needs of the AWattPrice App.
class UpdatedDataTimeFormatter {
    func localizedTimeString(for startDate: Date, relativeTo endDate: Date) -> String {
        let timeIntervalBetween = startDate.timeIntervalSince(endDate)

        if timeIntervalBetween < 60 {
            return "updateDataTimeFormatter.lessThanOneMinuteAgo".localized()
        } else {
            // More than one minute ago
            let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = 0
            let minutesBetweenString = numberFormatter.string(from: NSNumber(value: (timeIntervalBetween / 60).rounded(.down)))
            guard let _ = minutesBetweenString else { return "" }

            var localizableString = ""
            if timeIntervalBetween < 120 {
                localizableString = "updateDataTimeFormatter.moreThanMMAgoSingular"
            } else {
                localizableString = "updateDataTimeFormatter.moreThanMMAgoPlural"
            }

            return String(format: localizableString.localized(), minutesBetweenString!)
        }
    }
}

extension UpdatedDataView {
    class ViewModel: ObservableObject {
        @ObservedObject var energyDataService: EnergyDataService
        
        @Published var viewDownloadState = EnergyDataService.DownloadState.idle
        var startedDownloadingTime: Date? = nil
        
        @Published var firstAppear = true
        @Published var localizedTimeIntervalString: String = ""

        let dateFormatter = UpdatedDataTimeFormatter()
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        var downloadStateCancellable: AnyCancellable? = nil
        
        init(energyDataService: EnergyDataService) {
            self.energyDataService = energyDataService
            downloadStateCancellable = energyDataService.$downloadState.sink(receiveValue: updateDownloadState)
        }
        
        func updateDownloadState(newDownloadState: EnergyDataService.DownloadState) {
            switch newDownloadState {
            case .idle:
                viewDownloadState = .idle
            case .downloading:
                viewDownloadState = .downloading
                startedDownloadingTime = Date()
            case .finished(let downloadFinishedTime):
                if let startedDownloadingTime = startedDownloadingTime {
                    let startedFinishedDifference = downloadFinishedTime.timeIntervalSince(startedDownloadingTime)
                    let minimalDownloadingStateTime: TimeInterval = 0.7
                    if startedFinishedDifference > 0, startedFinishedDifference < minimalDownloadingStateTime {
                        let changeStateNowDifference = minimalDownloadingStateTime - startedFinishedDifference
                        DispatchQueue.main.asyncAfter(deadline: .now() + changeStateNowDifference) {
                            self.updateLocalizedTimeIntervalString(lastDownloadFinishedTime: downloadFinishedTime)
                            self.viewDownloadState = .finished(time: downloadFinishedTime)
                        }
                        return
                    }
                }
                updateLocalizedTimeIntervalString(lastDownloadFinishedTime: downloadFinishedTime)
                viewDownloadState = .finished(time: downloadFinishedTime)
            case .failed(let error):
                viewDownloadState = .failed(error: error)
            }
        }
        
        func updateLocalizedTimeIntervalString(lastDownloadFinishedTime: Date) {
            localizedTimeIntervalString = dateFormatter.localizedTimeString(for: Date(), relativeTo: lastDownloadFinishedTime)
        }
    }
}

struct UpdatedDataView: View {
    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var viewModel: ViewModel
    
    init() {
        // Initialize with temporary values that will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: ViewModel(
            energyDataService: EnergyDataService()
        ))
    }
    
    var body: some View {
        HStack(spacing: 10) {
            switch viewModel.viewDownloadState {
            case .downloading:
                Text("Loading")
                    .foregroundColor(Color.blue)
                    .transition(.opacity)
                
                ProgressView()
                    .foregroundColor(Color.blue)
                    .transition(.opacity)
                    .frame(width: 13, height: 13)
                    .scaleEffect(0.7, anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
            case .failed:
                Text("Couldn't get new data. Tap to retry.")
                    .foregroundColor(Color.red)
            case .idle, .finished:
                Text(viewModel.localizedTimeIntervalString)
                    .foregroundColor(Color.gray)
                    .transition(.opacity)
                    .animation(nil)
            }

            Spacer()
        }
        .font(.fCaption)
        .animation(.easeInOut)
        .onAppear {
            // Update viewModel with the actual environment objects
            viewModel.energyDataService = energyDataService
            
            if case .finished(let time) = viewModel.viewDownloadState {
                viewModel.updateLocalizedTimeIntervalString(lastDownloadFinishedTime: time)
            }
        }
        .onReceive(viewModel.timer) { _ in
            if case .finished(let time) = viewModel.viewDownloadState {
                viewModel.updateLocalizedTimeIntervalString(lastDownloadFinishedTime: time)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.energyDataService.download(region: settingsManager.setting.region, setting: settingsManager.setting)
        }
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
            .environmentObject(EnergyDataService())
    }
}
