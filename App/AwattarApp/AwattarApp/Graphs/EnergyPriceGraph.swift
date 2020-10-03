//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

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
                ? 0 : CGFloat(abs(singleBarSettings.minPrice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width) // Width of most negative price bar
        
        let negativePriceBarWidth = (
            singleBarSettings.minPrice != 0
                ? CGFloat(abs(hourDataPoint.marketprice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width : 0) // Width for the price bar for negative range
        
        let positivePriceBarWidth = (
            singleBarSettings.maxPrice != 0
                ? CGFloat(abs(hourDataPoint.marketprice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width + maximalNegativePriceBarWidth : 0) // Width for the price bar for positive range
      
        let currentDividerLineWidth = (
            maximalNegativePriceBarWidth == 0 ? 0 : singleBarSettings.verticalDividerLineWidth
        )
        
        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .center)) {
            var fillColor = LinearGradient(gradient: Gradient(colors: [Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059), Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            
//            Path { path in
//                if hourDataPoint.marketprice > 0 {
//                    path.move(to: CGPoint(x: maximalNegativePriceBarWidth + currentDividerLineWidth, y: startHeight + singleBarSettings.barHeightPadding))
//                    path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - singleBarSettings.radius + currentDividerLineWidth, y: startHeight + singleBarSettings.barHeightPadding + singleBarSettings.radius), radius: singleBarSettings.radius, startAngle: .degrees(270), delta: .degrees(180))
//                    path.addLine(to: CGPoint(x: positivePriceBarWidth + currentDividerLineWidth, y: startHeight + singleBarSettings.barHeightPadding + singleBarSettings.radius))
//                    path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - singleBarSettings.radius + currentDividerLineWidth, y: startHeight + height - singleBarSettings.barHeightPadding - singleBarSettings.radius), radius: singleBarSettings.radius, startAngle: .degrees(0), delta: .degrees(90))
//                    path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth + currentDividerLineWidth, y: startHeight + height - singleBarSettings.barHeightPadding))
//
//
//                } else if hourDataPoint.marketprice < 0 {
//                    let barStartWidth = maximalNegativePriceBarWidth - negativePriceBarWidth
//
//                    path.move(to: CGPoint(x: barStartWidth, y: startHeight + singleBarSettings.barHeightPadding))
//                    path.addRelativeArc(center: CGPoint(x: barStartWidth + singleBarSettings.radius, y: startHeight + singleBarSettings.radius + singleBarSettings.barHeightPadding), radius: singleBarSettings.radius, startAngle: .degrees(180), delta: .degrees(90))
//                    path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: startHeight + singleBarSettings.barHeightPadding))
//                    path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: startHeight + height - singleBarSettings.barHeightPadding))
//                    path.addRelativeArc(center: CGPoint(x: barStartWidth + singleBarSettings.radius, y: startHeight + height - singleBarSettings.barHeightPadding - singleBarSettings.radius), radius: singleBarSettings.radius, startAngle: .degrees(90), delta: .degrees(90))
//
//                    fillColor = LinearGradient(gradient: Gradient(colors: [Color.green, Color.gray]), startPoint: .leading, endPoint: .trailing)
//                }
//            }
//            .fill(fillColor)

//            if maximalNegativePriceBarWidth != 0 {
//                Path { path in
//                    let verticalDividerLineStartWidth = maximalNegativePriceBarWidth + (currentDividerLineWidth / 2)
//
//                    path.move(to: CGPoint(x: verticalDividerLineStartWidth, y: startHeight))
//                    path.addLine(to: CGPoint(x: verticalDividerLineStartWidth, y: height + startHeight))
//                }
//                .strokedPath(StrokeStyle(lineWidth: currentDividerLineWidth, lineCap: .square))
//                .foregroundColor(Color.black)
//            }

            if false {
                let horizontalLineStartHeight = (height / 2) - (singleBarSettings.horizontalDividerLineHeight / 2) + singleBarSettings.barHeightPadding

                Path { path in
                    path.move(to: CGPoint(x: 0, y: horizontalLineStartHeight))
                    path.addLine(to: CGPoint(x: width, y: horizontalLineStartHeight))
                    path.addLine(to: CGPoint(x: width, y: horizontalLineStartHeight + singleBarSettings.horizontalDividerLineHeight / 2))
                    path.addLine(to: CGPoint(x: 0, y: horizontalLineStartHeight + singleBarSettings.horizontalDividerLineHeight / 2))
                    path.addLine(to: CGPoint(x: 0, y: horizontalLineStartHeight))
                }
                .fill(Color.red)
            }

//            if currentSetting.setting!.pricesWithTaxIncluded {
//                // With tax
//                Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001 * 1.16)))!)
//                    .font(.caption)
//                    .position(x: 30, y: startHeight + (height / 2))
//                    .foregroundColor(Color.white)
//
//            } else if !currentSetting.setting!.pricesWithTaxIncluded {
//                // Without tax
//                Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001)))!)
//                    .font(.caption)
//                    .position(x: 30, y: startHeight + (height / 2))
//                    .foregroundColor(Color.white)
//            }
//
            HStack(spacing: 5) {
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.startTimestamp / 1000))))
                Text("-")
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.endTimestamp / 1000))))
            }
            .foregroundColor(Color.black)
            .padding(.leading, 3)
            .padding(.trailing, 3)
            .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hue: 0.6111, saturation: 0.0276, brightness: 0.8510)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(4)
            .shadow(radius: 2)
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
    let radius = CGFloat(4)
    
    let barHeight = CGFloat(30)
    
    let horizontalDividerLineHeight = CGFloat(5)
    let verticalDividerLineWidth = CGFloat(1)
    
    let barHeightPadding = CGFloat(4) // Padding kept to the top and to the bottom
    
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
    
    @State var graphHourPointData = [(EnergyPricePoint, CGFloat)]()
    
    @State var currentPointerHourHeight: (EnergyPricePoint, CGFloat)? = nil
    @State var pointerHeightDeltaToBefore: CGFloat? = nil

    var singleBarSettings = SingleBarSettings()
    
    @Binding var heightOfGraph: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            makeView(geometry)
        }
    }
    
    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let singleHeight = singleBarSettings.barHeight
        
        print("Make")
        
        let graphDragGesture = DragGesture(minimumDistance: 0)
            .onChanged { location in
                let locationHeight = location.location.y
                
                if (currentPointerHourHeight == nil) || !(locationHeight == currentPointerHourHeight!.1) {
                    if currentPointerHourHeight == nil {
                        pointerHeightDeltaToBefore = nil
                    } else {
                        pointerHeightDeltaToBefore = abs((currentPointerHourHeight!.1 + (singleHeight / 2)) - locationHeight)
                    }
                    
                    if pointerHeightDeltaToBefore == nil || pointerHeightDeltaToBefore! >= (singleHeight / 2) {
                        for hour in graphHourPointData {
                            if locationHeight >= hour.1 && locationHeight <= (hour.1 + singleHeight) {
    //                            withAnimation {
                                    currentPointerHourHeight = (hour.0, hour.1)
    //                            }
                            }
                        }
                    }
                }
            }
            .onEnded {_ in
//                withAnimation {
                    currentPointerHourHeight = nil
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
            
            if currentPointerHourHeight != nil {
                EnergyPriceSingleBarPointerHighlighter(
                    singleBarSettings: singleBarSettings,
                    width: width,
                    height: singleHeight,
                    startHeight: currentPointerHourHeight!.1,
                    hourDataPoint: currentPointerHourHeight!.0)
//                    .transition(.opacity)
//                    .animation(.linear(duration: 0))
                    .zIndex(1)
            }
        }
//        .gesture(graphDragGesture)
        .onAppear {
            var currentHeight: CGFloat = 0
            
            for hourPoint in awattarData.energyData!.awattar.prices {
                graphHourPointData.append((hourPoint, currentHeight))
                currentHeight += singleHeight
            }
            
            heightOfGraph = singleBarSettings.barHeight * CGFloat(graphHourPointData.count)
            
            if awattarData.energyData != nil {
                singleBarSettings.minPrice = awattarData.energyData!.awattar.minPrice
                singleBarSettings.maxPrice = awattarData.energyData!.awattar.minPrice
            }
        }
    }
}

struct EnergyPriceGraph_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            
        }
    }
}
