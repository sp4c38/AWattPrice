//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

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
    
    var animatableData: CGFloat {
        get { startHeight }
        set { self.startHeight = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 2
        let barPadding: CGFloat = 3
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
        if startHeight < 24 {
            print(height)
        }
        path.move(to: CGPoint(x: startWidth, y: startHeight))
        path.addLine(to: CGPoint(x: startWidth, y: height + startHeight))
        
        path = path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .square))

        return path
    }
}

struct AnimatableCustomFontModifier: AnimatableModifier {
    var size: CGFloat
    
    var animatableData: CGFloat {
        get { size }
        set { size = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
    }
}

extension View {
    func animatableFont(size: CGFloat) -> some View {
        self.modifier(AnimatableCustomFontModifier(size: size))
    }
}

struct EnergyPriceSingleBar: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var currentSetting: CurrentSetting

    let singleBarSettings: SingleBarSettings
    let width: CGFloat
    let height: CGFloat
    var startHeight: CGFloat
    let isSelected: Bool
    let hourDataPoint: EnergyPricePoint

    init(singleBarSettings: SingleBarSettings,
         width: CGFloat,
         height: CGFloat,
         startHeight: CGFloat,
         isSelected: Bool,
         hourDataPoint: EnergyPricePoint) {

        self.singleBarSettings = singleBarSettings
        self.width = width
        if isSelected {
            self.height = height + 20
            self.startHeight = startHeight - 10 // Should be half of which was added to height
        } else {
            self.height = height
            self.startHeight = startHeight
        }
        self.isSelected = isSelected
        self.hourDataPoint = hourDataPoint
    }

    var body: some View {
        let maximalNegativePriceBarWidth = (
            singleBarSettings.minPrice == 0
                ? 0 : CGFloat(abs(singleBarSettings.minPrice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width)

        let negativePriceBarWidth = (
            singleBarSettings.minPrice != 0
                ? CGFloat(abs(hourDataPoint.marketprice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width : 0)

        let positivePriceBarWidth = (
            singleBarSettings.maxPrice != 0
                ? CGFloat(abs(hourDataPoint.marketprice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width + maximalNegativePriceBarWidth : 0)

        let currentDividerLineWidth: CGFloat = (
            maximalNegativePriceBarWidth == 0 ? 0 : 3
        )
        
        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .center)) {
            if hourDataPoint.marketprice > 0 {
                BarShape(isSelected: isSelected, startWidth: maximalNegativePriceBarWidth, startHeight: startHeight, widthOfBar: positivePriceBarWidth + currentDividerLineWidth, heightOfBar: height, lookToSide: .right)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059), Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)]), startPoint: .leading, endPoint: .trailing))
            } else if hourDataPoint.marketprice < 0 {
                BarShape(isSelected: isSelected, startWidth: maximalNegativePriceBarWidth, startHeight: startHeight, widthOfBar: maximalNegativePriceBarWidth - negativePriceBarWidth, heightOfBar: height, lookToSide: .left)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.green, Color.gray]), startPoint: .leading, endPoint: .trailing))
            }

            if maximalNegativePriceBarWidth != 0 {//&& isSelected == false {
                VerticalDividerLineShape(width: currentDividerLineWidth, height: height, startWidth: maximalNegativePriceBarWidth, startHeight: startHeight)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            }

            VStack {
                if currentSetting.setting!.pricesWithTaxIncluded {
                    // With tax
                    Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001 * 1.16)))!)
                } else if !currentSetting.setting!.pricesWithTaxIncluded {
                    // Without tax
                    Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001)))!)
                }
            }
            .animatableFont(size: (isSelected ? 20 : 10))
            .position(x: 30, y: startHeight + (height / 2))
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)

//            if isSelected {
                HStack(spacing: 5) {
                    Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.startTimestamp))))
                    Text("-")
                    Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.endTimestamp))))
                }
                .animatableFont(size: (isSelected ? 20 : 10))
                .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                .padding(1)
                .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hue: 0.6111, saturation: 0.0276, brightness: 0.8510)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(4)
                .shadow(radius: 1)
                .position(x: 12 * (width / 13), y: startHeight + (height / 2))
//            }
        }
    }
}

class SingleBarSettings {
    var centFormatter: NumberFormatter
    var hourFormatter: DateFormatter
    
    var minPrice: Float = 0
    var maxPrice: Float = 0
        
    init() {
        centFormatter = NumberFormatter()
        centFormatter.numberStyle = .currency
        centFormatter.locale = Locale(identifier: "de_DE")
        centFormatter.currencySymbol = "ct"
        centFormatter.maximumFractionDigits = 2
        centFormatter.minimumFractionDigits = 2
        
        hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "H"
    }
}

struct EnergyPriceGraph: View {
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var graphHourPointData = [(EnergyPricePoint, CGFloat)]()

    @State var currentPointerIndex: Int? = nil
    @State var pointerHeightDeltaToBefore: CGFloat? = nil
    @State var singleHeight: CGFloat = 0
    
    var singleBarSettings = SingleBarSettings()
    
    var body: some View {
        GeometryReader { geometry in
            makeView(geometry)
        }
    }
    
    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height

        let graphDragGesture = DragGesture(minimumDistance: 0)
            .onChanged { location in
                let locationHeight = location.location.y
                
                if (currentPointerIndex == nil) || !(locationHeight == graphHourPointData[currentPointerIndex!].1) {
                    if currentPointerIndex == nil {
                        pointerHeightDeltaToBefore = nil
                    } else {
                        pointerHeightDeltaToBefore = abs((graphHourPointData[currentPointerIndex!].1 + (singleHeight / 2)) - locationHeight)
                    }

                    if pointerHeightDeltaToBefore == nil || pointerHeightDeltaToBefore! >= (singleHeight / 2) {
                        for hourPoint in 0..<graphHourPointData.count {
                            if locationHeight >= graphHourPointData[hourPoint].1 && locationHeight <= (graphHourPointData[hourPoint].1 + singleHeight) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentPointerIndex = hourPoint
//                                    print(graphHourPointData[hourPoint].1)
                                }
                            }
                        }
                    }
                }
            }
            .onEnded {_ in
                withAnimation {
                    currentPointerIndex = nil
                }
            }
        
        return ZStack {
            ZStack {
                ForEach(0..<graphHourPointData.count, id: \.self) { hourPointIndex in
                    let startHeight: CGFloat = (
                        (currentPointerIndex != nil) ?
                            ((hourPointIndex > currentPointerIndex!) ? graphHourPointData[hourPointIndex].1 + 30 :
                            (hourPointIndex < currentPointerIndex!) ? graphHourPointData[hourPointIndex].1 - 30 : graphHourPointData[hourPointIndex].1)
                        : graphHourPointData[hourPointIndex].1
                    )
                    
                    EnergyPriceSingleBar(
                        singleBarSettings: singleBarSettings,
                        width: width,
                        height: singleHeight,
                        startHeight: startHeight,
                        isSelected: ((hourPointIndex == currentPointerIndex) ? true : false),
                        hourDataPoint: graphHourPointData[hourPointIndex].0)
                }
            }
            .zIndex(0)
            .gesture(graphDragGesture)
        }
        .onAppear {
            singleHeight = height / CGFloat(awattarData.energyData!.prices.count)
            var currentHeight: CGFloat = 0

            for hourPointEntry in awattarData.energyData!.prices {
                graphHourPointData.append((hourPointEntry, currentHeight))
                currentHeight += singleHeight
            }

            singleBarSettings.minPrice = awattarData.energyData!.minPrice
            singleBarSettings.maxPrice = awattarData.energyData!.minPrice
        }
    }
}

struct EnergyPriceGraph_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            
        }
    }
}
