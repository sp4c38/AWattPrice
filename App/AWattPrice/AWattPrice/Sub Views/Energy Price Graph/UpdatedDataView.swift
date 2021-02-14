//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

struct UpdatedDataView: View {
    @Environment(\.networkManager) var networkManager

    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var currentSetting: CurrentSetting

    @State var firstAppear = true
    @State var localizedTimeIntervalString: String = ""

    let dateFormatter: UpdatedDataTimeFormatter
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        dateFormatter = UpdatedDataTimeFormatter()
    }
}

extension UpdatedDataView {
    func updateLocalizedTimeIntervalString() {
        if backendComm.dateDataLastUpdated != nil {
            localizedTimeIntervalString = dateFormatter.localizedTimeString(for: Date(), relativeTo: backendComm.dateDataLastUpdated!)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if backendComm.currentlyUpdatingData {
                Text("general.loading")
                    .foregroundColor(Color.blue)
                    .transition(.opacity)

                ProgressView()
                    .foregroundColor(Color.blue)
                    .transition(.opacity)
                    .frame(width: 13, height: 13)
                    .scaleEffect(0.7, anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if backendComm.dataRetrievalError == true {
                        Text("updateDataTimeFormatter.updateNewDataFailed")
                            .foregroundColor(Color.red)
                    } else {
                        if backendComm.dateDataLastUpdated != nil {
                            Text(localizedTimeIntervalString)
                                .foregroundColor(Color.gray)
                                .transition(.opacity)
                                .animation(nil)
                        }
                    }
                }
            }

            Spacer()
        }
        .font(.fCaption)
        .animation(.easeInOut)
        .onAppear {
            updateLocalizedTimeIntervalString()
        }
        .onReceive(timer) { _ in
            updateLocalizedTimeIntervalString()
        }
        .onChange(of: backendComm.currentlyUpdatingData) { newValue in
            if newValue == false {
                updateLocalizedTimeIntervalString()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let regionIdentifier = currentSetting.entity!.regionIdentifier
            backendComm.getEnergyData(regionIdentifier, networkManager)
        }
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
            .environmentObject(BackendCommunicator())
    }
}
