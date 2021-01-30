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
        let endX = rect.maxX
        let startY = rect.minY
        let endY = rect.maxY
        let width = rect.size.width
        let height = rect.size.height

        path.move(
            to: CGPoint(
                x: startX, // - (dividerLineWidth / 2),
                y: endY // + barPadding
            )
        )
        path.addLine(
            to:
                CGPoint(
                    x: endX,// - (dividerLineWidth / 2),
                    y: endY // - barPadding
                )
        )
        let radius = height / 14
        path.addRelativeArc(
            center:
                CGPoint(
                    x: width - radius,
                    y: startY + radius // - barPadding
                ),
                radius: radius,
                startAngle: .degrees(0),
                delta: .degrees(-90)
        )
        path.addRelativeArc(
            center:
                CGPoint(x: startX + radius,
                        y: startY + radius // + barPadding
                ),
            radius: radius,
            startAngle: .degrees(-90),
            delta: .degrees(-90)
        )
        path.addLine(
            to:
                CGPoint(
                    x: startX,// - (dividerLineWidth / 2),
                    y: endY // - barPadding
                )
        )
        return path
    }
}

struct GraphShape_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geometry in
            PointShape()
                .stroke()
                .frame(width: 100, height: 200)
                .position(
                    x: UIScreen.main.bounds.width / 2,
                    y: UIScreen.main.bounds.height - 148
                )
        }
    }
}
