//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

struct UpdatedDataView: View {
    @Environment(\.networkManager) var networkManager

    @EnvironmentObject var energyDataController: EnergyDataController
    @EnvironmentObject var currentSetting: CurrentSetting

    @State var firstAppear = true
    @State var localizedTimeIntervalString: String = ""

    let dateFormatter: UpdatedDataTimeFormatter
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        dateFormatter = UpdatedDataTimeFormatter()
    }
    
    func updateLocalizedTimeIntervalString(lastDownloadFinishedTime: Date) {
        localizedTimeIntervalString = dateFormatter.localizedTimeString(for: Date(), relativeTo: lastDownloadFinishedTime)
    }

    var body: some View {
        HStack(spacing: 10) {
            switch energyDataController.downloadState {
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
                Text(localizedTimeIntervalString)
                    .foregroundColor(Color.gray)
                    .transition(.opacity)
                    .animation(nil)
            }

            Spacer()
        }
        .font(.fCaption)
        .animation(.easeInOut)
        .onAppear {
            if case .finished(let time) = energyDataController.downloadState {
                updateLocalizedTimeIntervalString(lastDownloadFinishedTime: time)
            }
        }
        .onReceive(timer) { _ in
            if case .finished(let time) = energyDataController.downloadState {
                updateLocalizedTimeIntervalString(lastDownloadFinishedTime: time)
            }
        }
        .onReceive(energyDataController.$downloadState) { state in
            if case .finished(let time) = state {
                updateLocalizedTimeIntervalString(lastDownloadFinishedTime: time)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let region = Region(rawValue: currentSetting.entity!.regionIdentifier) {
                energyDataController.download(region: region)
            }
        }
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
    }
}
