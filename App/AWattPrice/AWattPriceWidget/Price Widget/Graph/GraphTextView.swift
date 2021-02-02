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
        VStack {
            TextAtPosition {
                    Text(graphText.content)
                        .font(.fCaption)
                        .bold()
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .padding([.leading, .trailing], 3)
                        .padding([.top, .bottom], 2)
                        .background(textBackground)
                        .cornerRadius(4)
                        .padding(.bottom, 5)
            }
        }
    }
}

extension GraphTextView {
    // Text positioning logic
    func TextAtPosition<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .modifier(SizeModifier())
            .onPreferenceChange(SizeModifierPreferenceKey.self) { newSize in
                contentSize = newSize
            }
            .position(
                x: graphText.startX,
                y: graphProperties.startY + graphProperties.allHeight
            )
            .offset(x: getOffsetX(), y: getOffsetY())
    }
    
    private func getOffsetX() -> CGFloat {
        let contentWidth = contentSize.width
        let pointWidth = graphProperties.pointWidth
        
        // Min x coordinate of the text box if it would be centered at the center of the graph point.
        let centeredMinX = (
            (graphText.startX + (pointWidth / 2)) // Center x coord of point
                - (contentWidth / 2)
        )
        // The text box if centered at the center of the graph point.
        let centeredFrame = CGRect(
            x: centeredMinX, y: 0, // Here, use 0 for y because it isn't needed/used.
            width: contentWidth, height: contentSize.height
        )
        
        var offset = centeredFrame.width / 2
    
        let maxX = graphProperties.endX
        // If the text box would be at graphText.startX/graphPoint.startX it would need to be x-offsetted by this value to be centered on the graph point.
        let xDiffForCentered = CGFloat(0)//-(centeredFrame.width / 4)
        
        if centeredFrame.minX < graphProperties.startX {
            print("Text is smaller than graph start: \(graphText.content) by \(0 + centeredFrame.minX).")
        } else if centeredFrame.maxX > maxX {
            let contentOvercover = (
                (centeredFrame.maxX - xDiffForCentered) // Text end x if text positioned at graphText.startX
                - maxX
            )
            offset -= contentOvercover
        } else {
            offset += xDiffForCentered
        }
        
        return offset
    }
    
    private func getOffsetY() -> CGFloat {
        return -(contentSize.height / 2) - graphProperties.textPaddings[.bottom]!
    }
}

extension GraphTextView {
    var textBackground: some View {
        if colorScheme == .light {
            return Color(red: 0.92, green: 0.91, blue: 0.93)
                .opacity(0.7)
        } else {
            return Color(red: 0.21, green: 0.21, blue: 0.21)
                .opacity(0.7)
        }
    }
}
