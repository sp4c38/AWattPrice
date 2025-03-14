//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import Combine
import SwiftUI

extension UpdatedDataView {
    class ViewModel: ObservableObject {
        @ObservedObject var energyDataService: EnergyDataService
        @ObservedObject var setting: SettingCoreData
        
        @Published var viewDownloadState = EnergyDataService.DownloadState.idle
        var startedDownloadingTime: Date? = nil
        
        @Published var firstAppear = true
        @Published var localizedTimeIntervalString: String = ""

        let dateFormatter = UpdatedDataTimeFormatter()
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        var downloadStateCancellable: AnyCancellable? = nil
        
        init(energyDataService: EnergyDataService, setting: SettingCoreData) {
            self.energyDataService = energyDataService
            self.setting = setting
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
    @EnvironmentObject var setting: SettingCoreData
    @StateObject private var viewModel: ViewModel
    
    init() {
        // Initialize with temporary values that will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: ViewModel(
            energyDataService: EnergyDataService(),
            setting: SettingCoreData(viewContext: CoreDataService.shared.container.viewContext)
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
            viewModel.setting = setting
            
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
            if let region = Region(rawValue: viewModel.setting.entity.regionIdentifier) {
                viewModel.energyDataService.download(region: region)
            }
        }
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
            .environmentObject(EnergyDataService())
            .environmentObject(SettingCoreData(viewContext: CoreDataService.shared.container.viewContext))
    }
}
