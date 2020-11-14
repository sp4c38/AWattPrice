//
//  Shapes.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

/// A single bar with a certain length to represent the energy price relative to all other hours
struct BarShape: Shape {
    let isSelected: Bool
    let startWidth: CGFloat
    var startHeight: CGFloat
    let widthOfBar: CGFloat
    var heightOfBar: CGFloat
    
    enum SidesToLook {
        case right
        case left
    }
    
    let lookToSide: SidesToLook
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { return AnimatablePair(startHeight, heightOfBar) }
        set {
            self.startHeight = newValue.first
            self.heightOfBar = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 2
        let barPadding: CGFloat = 1
        let dividerLineWidth: CGFloat = 3
        
        var path = Path()
        
        if lookToSide == .left {
            path.move(to: CGPoint(x: startWidth - (dividerLineWidth / 2), y: startHeight + barPadding))
            path.addLine(to: CGPoint(x: startWidth - (dividerLineWidth / 2), y: startHeight + heightOfBar - barPadding))
            path.addRelativeArc(center: CGPoint(x: widthOfBar + radius, y: startHeight + heightOfBar - radius - barPadding), radius: radius, startAngle: .degrees(90), delta: .degrees(90))
            path.addRelativeArc(center: CGPoint(x: widthOfBar + radius, y: startHeight + barPadding + radius), radius: radius, startAngle: .degrees(180), delta: .degrees(90))
        } else if lookToSide == .right {
            path.move(to: CGPoint(x: startWidth + (dividerLineWidth / 2), y: startHeight + barPadding))
            path.addRelativeArc(center: CGPoint(x: widthOfBar - radius, y: startHeight + barPadding + radius), radius: radius, startAngle: .degrees(270), delta: .degrees(180))
            path.addLine(to: CGPoint(x: widthOfBar, y: startHeight + barPadding + radius))
            path.addRelativeArc(center: CGPoint(x: widthOfBar - radius, y: startHeight + heightOfBar - barPadding - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
            path.addLine(to: CGPoint(x: startWidth + (dividerLineWidth / 2), y: startHeight + heightOfBar - barPadding))
        }

        return path
    }
}

/// A simple line at a certain coordinate which shows the passage from positive energy prices to negative energy prices. It supports animation when the height  of this line is changed.
struct VerticalDividerLineShape: Shape {
    let width: CGFloat
    var height: CGFloat
    let startWidth: CGFloat
    var startHeight: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(startHeight, height) }
        set {
            startHeight = newValue.first
            height = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: startWidth, y: startHeight))
        path.addLine(to: CGPoint(x: startWidth, y: height + startHeight))
        
        path = path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .square))

        return path
    }
}
