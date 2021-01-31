//
//  GraphTextView.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct GraphTextView: View {
    let graphText: GraphText

    init(_ graphText: GraphText, graphProperties: GraphProperties) {
        self.graphText = graphText
    }
    
    var body: some View {
        TextAtPosition {
            VStack {
                Spacer()
                Text(graphText.content)
                    .bold()
                    .foregroundColor(.black)
            }
            .padding(.bottom, 6)
        }
    }
}

extension GraphTextView {
    func TextAtPosition<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .position(x: graphText.startX, y: 0)
    }
}
