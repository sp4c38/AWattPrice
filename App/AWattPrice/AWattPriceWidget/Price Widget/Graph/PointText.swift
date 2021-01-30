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
        Text(transformStartToString())
    }
}

extension PointText {
    private func transformStartToString() -> String {
        
        return ""
    }
}
