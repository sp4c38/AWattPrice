//
//  GraphTextView.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct SizeModifierPreferenceKey: PreferenceKey {
    static var defaultValue = CGSize(width: 0, height: 0)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct SizeModifier: ViewModifier {
    var backgroundSizeView: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: SizeModifierPreferenceKey.self, value: geometry.size)
        }
    }
    
    func body(content: Content) -> some View {
        content.background(
            backgroundSizeView
        )
    }
}

struct GraphTextView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var contentSize = CGSize(width: 0, height: 0)
    
    let graphText: GraphText
    let graphProperties: GraphProperties

    init(_ graphText: GraphText, graphProperties: GraphProperties) {
        self.graphText = graphText
        self.graphProperties = graphProperties
    }
    
    var body: some View {
        TextAtPosition {
            Text(graphText.content)
                .font(.fCaption)
                .bold()
                .foregroundColor(colorScheme == .light ? .black : .white)
//                .padding(.bottom, 5)
                .background(textBackground)
        }
    }
}

extension GraphTextView {
    // Text positioning logic
    func TextAtPosition<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .modifier(SizeModifier())
            .onPreferenceChange(SizeModifierPreferenceKey.self) { newSize in
                self.contentSize = newSize
            }
            .position(
                x: graphText.startX,
                y: graphProperties.startY + graphProperties.allHeight
            )
            .offset(x: getOffsetX(), y: getOffsetY())
    }
    
    func getOffsetX() -> CGFloat {
        let textWidth = contentSize.width
        
        let pointWidth = graphProperties.pointWidth
        var offset: CGFloat = textWidth / 2
        
        
        return offset
    }
    
    func getOffsetY() -> CGFloat {
        return -(contentSize.height / 2) - 20
    }
}

extension GraphTextView {
    var textBackground: some View {
        VStack {
            if colorScheme == .light {
                Color(red: 0.92, green: 0.91, blue: 0.93)
            } else {
                Color(red: 0.21, green: 0.21, blue: 0.21)
            }
        }
    }
}
