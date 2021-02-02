//
//  GraphPointView.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

func getPointLinearColor(isNegative: Bool) -> LinearGradient {
    var gradient: Gradient?
    
    if isNegative {
        gradient = Gradient(
            colors: [
                Color.gray,
                Color.green
            ]
        )
    } else {
        gradient = Gradient(
            colors: [
                Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059),
                Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)
            ]
        )
    }
    
    let linearGradient = LinearGradient(
        gradient: gradient!,
        startPoint: .top, endPoint: .bottom
    )
    return linearGradient
}

struct GraphPointView: View {
    let graphPoint: GraphPoint
    let graphProperties: GraphProperties
    
    init(_ graphPoint: GraphPoint, graphProperties: GraphProperties) {
        self.graphPoint = graphPoint
        self.graphProperties = graphProperties
    }
    
    var body: some View {
        ZStack {
            PointAtPosition {
                PointShape(graphProperties)
                    .fill(getPointLinearColor(isNegative: graphPoint.isNegative))
            }
        }
    }
}

extension GraphPointView {
    func PointAtPosition<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: graphProperties.pointWidth, height: graphPoint.height)
            .position(
                x: graphPoint.startX + (graphProperties.pointWidth / 2),
                y: graphPoint.startY + (graphPoint.height / 2)
            )
    }
}

//struct GraphPoint_Previews: PreviewProvider {
//    static var previews: some View {
//        GraphPoint()
//    }
//}
