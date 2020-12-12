//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

struct UpdatedDataView: View {
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var firstAppear = true
    @State var localizedTimeIntervalString: String = ""
    
    let dateFormatter: UpdatedDataTimeFormatter
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init() {
        self.dateFormatter = UpdatedDataTimeFormatter()
    }
    
    func updateLocalizedTimeIntervalString() {
        if awattarData.dateDataLastUpdated != nil {
            localizedTimeIntervalString = dateFormatter.localizedTimeString(for: Date(), relativeTo: awattarData.dateDataLastUpdated!)
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            if awattarData.currentlyUpdatingData {
                Text("loading")
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
                    if awattarData.dataRetrievalError == true {
                        Text("updateNewDataFailed")
                            .foregroundColor(Color.red)
                    } else {
                        if awattarData.dateDataLastUpdated != nil {
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
        .font(.caption)
        .animation(.easeInOut)
        .onAppear {
            updateLocalizedTimeIntervalString()
        }
        .onReceive(timer) { _ in
            updateLocalizedTimeIntervalString()
        }
        .onChange(of: awattarData.currentlyUpdatingData) { newValue in
            if newValue == false {
                updateLocalizedTimeIntervalString()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            awattarData.download(forRegion: currentSetting.setting!.regionSelection)
        }
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
            .environmentObject(AwattarData())
    }
}
