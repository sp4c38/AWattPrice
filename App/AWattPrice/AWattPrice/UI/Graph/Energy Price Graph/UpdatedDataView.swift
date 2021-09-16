//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import Combine
import Resolver
import SwiftUI

extension UpdatedDataView {
    class ViewModel: ObservableObject {
        @ObservedObject var energyDataController: EnergyDataController = Resolver.resolve()
        @Injected var currentSetting: CurrentSetting
        
        @Published var viewDownloadState = EnergyDataController.DownloadState.idle
        var startedDownloadingTime: Date? = nil
        
        @Published var firstAppear = true
        @Published var localizedTimeIntervalString: String = ""

        let dateFormatter = UpdatedDataTimeFormatter()
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        var downloadStateCancellable: AnyCancellable? = nil
        
        init() {
            downloadStateCancellable = energyDataController.$downloadState.sink(receiveValue: updateDownloadState)
        }
        
        func updateDownloadState(newDownloadState: EnergyDataController.DownloadState) {
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
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        HStack(spacing: 10) {
            switch viewModel.viewDownloadState {
            case .downloading:
                Text("general.loading")
                    .foregroundColor(Color.blue)
                    .transition(.opacity)
                
                ProgressView()
                    .foregroundColor(Color.blue)
                    .transition(.opacity)
                    .frame(width: 13, height: 13)
                    .scaleEffect(0.7, anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
            case .failed:
                Text("updateDataTimeFormatter.updateNewDataFailed")
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
            if let region = Region(rawValue: viewModel.currentSetting.entity!.regionIdentifier) {
                viewModel.energyDataController.download(region: region)
            }
        }
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
    }
}
