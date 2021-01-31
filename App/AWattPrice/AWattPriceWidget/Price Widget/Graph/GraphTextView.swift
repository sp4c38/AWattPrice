//
//  GraphTextView.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct GraphTextView: View {
    let graphText: GraphText

    init(_ graphText: GraphText) {
        self.graphText = graphText
    }
    
    var body: some View {
        VStack {
            Spacer()
            Text(graphText.content)
                .bold()
                .foregroundColor(.white)
        }
        .padding(.bottom, 6)
    }
}

extension GraphTextView {
    func TextAtPosition<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .position(x: 0, y: 0)
    }
}
