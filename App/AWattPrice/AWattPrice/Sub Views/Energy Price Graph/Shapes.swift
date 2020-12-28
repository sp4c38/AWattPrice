//
//  Shapes.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

/// A single bar with a certain length to represent the energy price relative to all other hours
struct BarShape: Shape {
    class BarShapeAttributes {
        enum SidesToLook {
            case right
            case left
        }
        
        let isSelected: Bool
        let lookToSide: SidesToLook
        
        let startWidth: CGFloat
        var startHeight: CGFloat
        let widthOfBar: CGFloat
        var heightOfBar: CGFloat
        
        let radius: CGFloat
        let barPadding: CGFloat // Padding between different bars
        let dividerLineWidth: CGFloat
        
        init(isSelected: Bool, startWidth: CGFloat, startHeight: CGFloat, widthOfBar: CGFloat, heightOfBar: CGFloat, lookToSide: SidesToLook) {
            self.isSelected = isSelected
            self.lookToSide = lookToSide
            
            self.startWidth = startWidth
            self.startHeight = startHeight
            self.widthOfBar = widthOfBar
            self.heightOfBar = heightOfBar
            
            self.radius = heightOfBar / 14
            self.barPadding = 1
            self.dividerLineWidth = 3
        }
    }
    let attr: BarShapeAttributes
    
    var startHeight: CGFloat
    var heightOfBar: CGFloat
    
    init(barShapeAttributes: BarShapeAttributes) {
        self.attr = barShapeAttributes
        self.startHeight = attr.startHeight
        self.heightOfBar = attr.heightOfBar
    }
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { return AnimatablePair(self.startHeight, self.heightOfBar) }
        set {
            self.startHeight = newValue.first
            self.heightOfBar = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        if attr.lookToSide == .left {
            path.move(to: CGPoint(x: attr.startWidth - (attr.dividerLineWidth / 2), y: startHeight + attr.barPadding))
            
            path.addLine(to: CGPoint(x: attr.startWidth - (attr.dividerLineWidth / 2), y: startHeight + heightOfBar - attr.barPadding))
            
            path.addRelativeArc(center: CGPoint(x: attr.widthOfBar + attr.radius, y: startHeight + heightOfBar - attr.radius - attr.barPadding), radius: attr.radius, startAngle: .degrees(90), delta: .degrees(90))
            
            path.addRelativeArc(center: CGPoint(x: attr.widthOfBar + attr.radius, y: startHeight + attr.barPadding + attr.radius), radius: attr.radius, startAngle: .degrees(180), delta: .degrees(90))
            
        } else if attr.lookToSide == .right {
            path.move(to: CGPoint(x: attr.startWidth + (attr.dividerLineWidth / 2), y: startHeight + attr.barPadding))
            
            path.addRelativeArc(center: CGPoint(x: attr.widthOfBar - attr.radius, y: startHeight + attr.barPadding + attr.radius), radius: attr.radius, startAngle: .degrees(270), delta: .degrees(180))
            
            path.addLine(to: CGPoint(x: attr.widthOfBar, y: startHeight + attr.barPadding + attr.radius))
            path.addRelativeArc(center: CGPoint(x: attr.widthOfBar - attr.radius, y: startHeight + heightOfBar - attr.barPadding - attr.radius), radius: attr.radius, startAngle: .degrees(0), delta: .degrees(90))
            
            path.addLine(to: CGPoint(x: attr.startWidth + (attr.dividerLineWidth / 2), y: startHeight + heightOfBar - attr.barPadding))
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

struct DayMarkView: View {
    @Environment(\.colorScheme) var colorScheme
    
    struct DayMarkLineShape: Shape {
        var startHeight: CGFloat
        var lineWidth: CGFloat
        var widthDiff: CGFloat
        
        var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
            get { AnimatablePair(self.startHeight, AnimatablePair(self.widthDiff, self.lineWidth)) }
            set {
                self.startHeight = newValue.first
                self.widthDiff = newValue.second.first
                self.lineWidth = newValue.second.second
            }
        }
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.width - 76 + widthDiff, y: startHeight))
            path.addLine(to: CGPoint(x: rect.width, y: startHeight))
            path = path.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .square))
            return path
        }
    }
    
    struct DayMarkCircleShape: Shape {
        var startHeight: CGFloat
        var widthDiff: CGFloat
        var sizeDiff: CGFloat
        
        var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
            get { AnimatablePair(self.startHeight, AnimatablePair(self.widthDiff, self.sizeDiff)) }
            set {
                self.startHeight = newValue.first
                self.widthDiff = newValue.second.first
                self.sizeDiff = newValue.second.second
            }
        }
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addArc(center: CGPoint(x: rect.width - 76 + widthDiff, y: startHeight), radius: 2 + sizeDiff, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
            return path
        }
        
    }
    
    var graphPointItem: EnergyPricePoint
    var startHeight: CGFloat
    var widthDiff: CGFloat
    var sizeDiff: CGFloat
    
    init(graphPointItem: (EnergyPricePoint, CGFloat), indexSelected: Int?, ownIndex: Int, maxIndex: Int, height: CGFloat) {
        self.graphPointItem = graphPointItem.0
        
        let results = calcSingleBarSizes(indexSelected, graphPointItem.1, ownIndex, maxIndex, height)
        self.startHeight = results.0
        
        self.widthDiff = 0
        self.sizeDiff = 0
        if indexSelected != nil {
            if indexSelected == ownIndex || indexSelected! + 1 == ownIndex {
                widthDiff =  -25
                sizeDiff = 1
            }
        }
    }
    
    var body: some View {
        ZStack {
            DayMarkLineShape(startHeight: self.startHeight, lineWidth: 3 + sizeDiff, widthDiff: widthDiff)
                .foregroundColor(colorScheme == .light ? Color.white : Color.black)
            DayMarkLineShape(startHeight: self.startHeight, lineWidth: 1 + sizeDiff, widthDiff: widthDiff)
                .foregroundColor(Color.red)
            
            DayMarkCircleShape(startHeight: self.startHeight, widthDiff: widthDiff, sizeDiff: sizeDiff + 1)
                .foregroundColor(colorScheme == .light ? Color.white : Color.black)
            DayMarkCircleShape(startHeight: self.startHeight, widthDiff: widthDiff, sizeDiff: sizeDiff)
                .foregroundColor(Color.red)
        }
    }
}
