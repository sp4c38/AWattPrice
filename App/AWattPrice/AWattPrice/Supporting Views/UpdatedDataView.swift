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
                if awattarData.currentlyUpdatingData {
                    ProgressView()
                }
                
                Text(dateFormatter.string(from: awattarData.dateDataLastUpdated!))
                    .foregroundColor(awattarData.currentlyUpdatingData ? Color.gray : Color.green)
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
