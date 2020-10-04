//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

struct BarShape: Shape {
    let startWidth: CGFloat
    let startHeight: CGFloat
    let widthOfBar: CGFloat
    let heightOfBar: CGFloat
    
    enum SidesToLook {
        case right
        case left
    }
    
    let lookToSide: SidesToLook
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 4
        let barPadding: CGFloat = 3
        let dividerLineWidth: CGFloat = 3
        
        var path = Path()
        
        if lookToSide == .left {
            path.move(to: CGPoint(x: startWidth, y: startHeight + barPadding))
            path.addLine(to: CGPoint(x: startWidth, y: startHeight + heightOfBar - barPadding))
            path.addRelativeArc(center: CGPoint(x: widthOfBar + radius, y: startHeight + heightOfBar - radius - barPadding), radius: radius, startAngle: .degrees(90), delta: .degrees(90))
            path.addRelativeArc(center: CGPoint(x: widthOfBar + radius, y: startHeight + barPadding + radius), radius: radius, startAngle: .degrees(180), delta: .degrees(90))
        } else if lookToSide == .right {
            path.move(to: CGPoint(x: startWidth, y: startHeight + barPadding))
            path.addRelativeArc(center: CGPoint(x: widthOfBar - radius, y: startHeight + barPadding + radius), radius: radius, startAngle: .degrees(270), delta: .degrees(180))
            path.addLine(to: CGPoint(x: widthOfBar, y: startHeight + barPadding + radius))
            path.addRelativeArc(center: CGPoint(x: widthOfBar - radius, y: startHeight + heightOfBar - barPadding - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
            path.addLine(to: CGPoint(x: startWidth, y: startHeight + heightOfBar - barPadding))
        }

        return path
    }
}

struct EnergyPriceSingleBar: View {
    @EnvironmentObject var currentSetting: CurrentSetting

    let singleBarSettings: SingleBarSettings
    let width: CGFloat
    let height: CGFloat
    let startHeight: CGFloat
    let hourDataPoint: EnergyPricePoint

    init(singleBarSettings: SingleBarSettings,
         width: CGFloat,
         height: CGFloat,
         startHeight: CGFloat,
         hourDataPoint: EnergyPricePoint) {

        self.singleBarSettings = singleBarSettings
        self.width = width
        self.height = height
        self.startHeight = startHeight
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

        let currentDividerLineWidth = (
            maximalNegativePriceBarWidth == 0 ? 0 : singleBarSettings.verticalDividerLineWidth
        )
        
        let radius = 4

        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .center)) {
            if hourDataPoint.marketprice > 0 {
                BarShape(startWidth: maximalNegativePriceBarWidth, startHeight: startHeight, widthOfBar: positivePriceBarWidth + currentDividerLineWidth, heightOfBar: height, lookToSide: .right)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059), Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)]), startPoint: .leading, endPoint: .trailing))
            } else if hourDataPoint.marketprice < 0 {
                BarShape(startWidth: maximalNegativePriceBarWidth, startHeight: startHeight, widthOfBar: maximalNegativePriceBarWidth - negativePriceBarWidth, heightOfBar: height, lookToSide: .left)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.green, Color.gray]), startPoint: .leading, endPoint: .trailing))
            }

            if maximalNegativePriceBarWidth != 0 {
                Path { path in
                    let verticalDividerLineStartWidth = maximalNegativePriceBarWidth + (currentDividerLineWidth / 2)

                    path.move(to: CGPoint(x: verticalDividerLineStartWidth, y: startHeight))
                    path.addLine(to: CGPoint(x: verticalDividerLineStartWidth, y: height + startHeight))
                }
                .strokedPath(StrokeStyle(lineWidth: currentDividerLineWidth, lineCap: .square))
                .foregroundColor(Color.black)
            }
            
            if currentSetting.setting!.pricesWithTaxIncluded {
                // With tax
                Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001 * 1.16)))!)
                    .font(.caption)
                    .position(x: 30, y: startHeight + (height / 2))
                    .foregroundColor(Color.black)

            } else if !currentSetting.setting!.pricesWithTaxIncluded {
                // Without tax
                Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001)))!)
                    .font(.caption)
                    .position(x: 30, y: startHeight + (height / 2))
                    .foregroundColor(Color.black)
            }

            HStack(spacing: 5) {
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.startTimestamp / 1000))))
                Text("-")
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.endTimestamp / 1000))))
            }
            .font(.system(size: height / 2))
            .foregroundColor(Color.black)
            .padding(1)
            .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hue: 0.6111, saturation: 0.0276, brightness: 0.8510)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(4)
            .shadow(radius: 1)
            .position(x: 320, y: startHeight + (height / 2))
        }
    }
}

struct EnergyPriceSingleBarPointerHighlighter: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    
    let singleBarSettings: SingleBarSettings
    let width: CGFloat
    let height: CGFloat
    let startHeight: CGFloat
    let hourDataPoint: EnergyPricePoint
    
    init(singleBarSettings: SingleBarSettings,
         width: CGFloat,
         height: CGFloat,
         startHeight: CGFloat,
         hourDataPoint: EnergyPricePoint) {
        
        self.singleBarSettings = singleBarSettings
        self.width = width
        self.height = height
        self.startHeight = startHeight
        self.hourDataPoint = hourDataPoint
    }
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: startHeight + (height / 2)))
            path.addLine(to: CGPoint(x: width - 5, y: startHeight + (height / 2)))
        }
        .strokedPath(StrokeStyle(lineWidth: singleBarSettings.horizontalDividerLineHeight, lineCap: .round))
    }
}

class SingleBarSettings {
    var centFormatter: NumberFormatter
    var hourFormatter: DateFormatter
    
    var minPrice: Float = 0
    var maxPrice: Float = 0
    
    let horizontalDividerLineHeight = CGFloat(2)
    let verticalDividerLineWidth = CGFloat(1)
        
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

    var singleBarSettings = SingleBarSettings()
    
    var body: some View {
        GeometryReader { geometry in
            makeView(geometry)
        }
    }
    
    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        let singleHeight: CGFloat
        
        singleHeight = height / CGFloat(awattarData.energyData!.awattar.prices.count)
        
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
    //                            withAnimation {
                                currentPointerIndex = hourPoint
                                print(graphHourPointData[hourPoint].1)
    //                            }
                            }
                        }
                    }
                }
            }
            .onEnded {_ in
//                withAnimation {
                    currentPointerIndex = nil
//                }
            }
        
        return ZStack {
            ZStack {
                ForEach(graphHourPointData, id: \.0.startTimestamp) { hourPoint in
                    EnergyPriceSingleBar(
                        singleBarSettings: singleBarSettings,
                        width: width,
                        height: singleHeight,
                        startHeight: hourPoint.1,
                        hourDataPoint: hourPoint.0)
                }
            }
            .zIndex(0)
            .gesture(graphDragGesture)

            if currentPointerIndex != nil {
                EnergyPriceSingleBarPointerHighlighter(
                    singleBarSettings: singleBarSettings,
                    width: width,
                    height: singleHeight,
                    startHeight: graphHourPointData[currentPointerIndex!].1,
                    hourDataPoint: graphHourPointData[currentPointerIndex!].0)
//                    .transition(.opacity)
//                    .animation(.linear(duration: 0))
                    .zIndex(1)
                    .onAppear {
                        
                    }
            }
        }
        .onAppear {
            var currentHeight: CGFloat = 0
            
            for hourPoint in awattarData.energyData!.awattar.prices {
                graphHourPointData.append((hourPoint, currentHeight))
                currentHeight += singleHeight
            }
            
            if awattarData.energyData != nil {
                singleBarSettings.minPrice = awattarData.energyData!.awattar.minPrice
                singleBarSettings.maxPrice = awattarData.energyData!.awattar.minPrice
            }
            
            print(graphHourPointData)
        }
    }
}

struct EnergyPriceGraph_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            
        }
    }
}
