//
//  GraphShapes.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct PointShape: Shape {
    let barPadding: CGFloat = 1
    let dividerLineWidth: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.minX
        let startY = rect.minY
        let width = rect.size.width
        let height = rect.size.height

        path.move(
            to: CGPoint(
                x: startX - (dividerLineWidth / 2),
                y: startY + barPadding
            )
        )
        path.addLine(
            to:
                CGPoint(
                    x: startX - (dividerLineWidth / 2),
                    y: startY + height - barPadding
                )
        )
        let radius = height / 14
        path.addRelativeArc(
            center:
                CGPoint(
                    x: width + radius,
                    y: startY + height - radius - barPadding
                ),
                radius: radius,
                startAngle: .degrees(90),
                delta: .degrees(90)
        )
        path.addRelativeArc(
            center:
                CGPoint(x: width + radius,
                        y: startY + barPadding + radius),
            radius: radius,
            startAngle: .degrees(180),
            delta: .degrees(90)
        )
        
        return path
    }
}
