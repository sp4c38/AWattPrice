//
//  PointShape.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct PointShape: Shape {
    let pointSpacing: CGFloat
    let radius: CGFloat

    init(_ graphProperties: GraphProperties) {
        pointSpacing = graphProperties.pointSpacing / 2
        radius = 2
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.minX
        let endX = rect.maxX
        let startY = rect.minY
        let endY = rect.maxY
        let width = rect.size.width

        path.move(
            to: CGPoint(
                x: startX + pointSpacing,
                y: endY
            )
        )
        path.addLine(
            to:
                CGPoint(
                    x: endX - pointSpacing,
                    y: endY
                )
        )
        path.addRelativeArc(
            center:
                CGPoint(
                    x: width - radius - pointSpacing,
                    y: startY + radius
                ),
                radius: radius,
                startAngle: .degrees(0),
                delta: .degrees(-90)
        )
        path.addRelativeArc(
            center:
                CGPoint(x: startX + radius + pointSpacing,
                        y: startY + radius
                ),
            radius: radius,
            startAngle: .degrees(-90),
            delta: .degrees(-90)
        )
        path.addLine(
            to:
                CGPoint(
                    x: startX + pointSpacing,
                    y: endY
                )
        )
        return path
    }
}
