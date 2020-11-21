//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

struct UpdatedDataView: View {
    @EnvironmentObject var awattarData: AwattarData
    
    let dateFormatter: DateFormatter
    
    init() {
        self.dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Text("lastUpdated")
            
            Spacer()
            
            if awattarData.dateDataLastUpdated != nil {
                HStack(spacing: 10) {
                    if awattarData.currentlyUpdatingData {
                        ProgressView()
                            .transition(.opacity)
                        
                        Text("Updating")
                            .foregroundColor(Color.gray)
                            .transition(.opacity)
                    } else {
                        Text(dateFormatter.string(from: awattarData.dateDataLastUpdated!))
                            .foregroundColor(awattarData.currentlyUpdatingData ? Color.gray : Color.green)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut)
            }
        }
        .font(.subheadline)
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
            .environmentObject(AwattarData())
    }
}
