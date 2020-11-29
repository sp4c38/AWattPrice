//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

struct UpdatedDataView: View {
    @EnvironmentObject var awattarData: AwattarData
    
    @State var firstAppear = true
    @State var localizedTimeIntervalString: String = ""
    
    let dateFormatter: UpdatedDataTimeFormatter
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init() {
        self.dateFormatter = UpdatedDataTimeFormatter()
    }
    
    var body: some View {
        if awattarData.dateDataLastUpdated != nil {
            HStack(spacing: 10) {
                if awattarData.currentlyUpdatingData {
                    Text("updatingData")
                        .transition(.opacity)
                    
                    ProgressView()
                        .transition(.opacity)
                        .frame(width: 13, height: 13)
                        .scaleEffect(0.7, anchor: .center)
                } else {
                    Text(localizedTimeIntervalString)
                        .foregroundColor(Color.gray)
                        .transition(.opacity)
                }
                
                Spacer()
            }
            .font(.caption)
            .animation(.easeInOut)
            .onAppear {
                localizedTimeIntervalString = dateFormatter.localizedTimeString(for: Date(), relativeTo: awattarData.dateDataLastUpdated!)
            }
            .onReceive(timer) { _ in
                localizedTimeIntervalString = dateFormatter.localizedTimeString(for: Date(), relativeTo: awattarData.dateDataLastUpdated!)
            }
        }
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
            .environmentObject(AwattarData())
    }
}
