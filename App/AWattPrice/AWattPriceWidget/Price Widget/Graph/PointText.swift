//
//  PointText.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct PointText: View {
    let startTime: Date
    
    init(_ pointStartTime: Date) {
        startTime = pointStartTime
    }
    
    var body: some View {
        VStack {
            Spacer()
            Text(transformStartToString())
                .bold()
                .foregroundColor(.white)
        }
        .padding(.bottom, 6)
    }
}

extension PointText {
    private func transformStartToString() -> String {
        let hour = Calendar.current.component(.hour, from: startTime)
        return String(hour)
    }
}
