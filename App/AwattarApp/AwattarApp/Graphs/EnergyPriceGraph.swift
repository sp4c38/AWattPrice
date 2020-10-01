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
    let minPrice: Float
    let maxPrice: Float
    
    init(singleBarSettings: SingleBarSettings,
         width: CGFloat,
         height: CGFloat,
         startHeight: CGFloat,
         hourDataPoint: EnergyPricePoint,
         minPrice: Float,
         maxPrice: Float) {
        
        self.singleBarSettings = singleBarSettings
        self.width = width
        self.height = height
        self.startHeight = startHeight
        self.hourDataPoint = hourDataPoint
        self.minPrice = minPrice
        self.maxPrice = maxPrice
    }
    
    var body: some View {
        let maximalNegativePriceBarWidth = (
            minPrice != 0
                ? CGFloat(abs(minPrice) / (abs(minPrice) + abs(maxPrice))) * width : 0) // Width of most negative price bar
        
        let negativePriceBarWidth = (
            minPrice != 0
                ? CGFloat(abs(hourDataPoint.marketprice) / (abs(minPrice) + abs(maxPrice))) * width : 0) // Width for the price bar for negative range
        
        let positivePriceBarWidth = (
            maxPrice != 0
                ? CGFloat(abs(hourDataPoint.marketprice) / (abs(minPrice) + abs(maxPrice))) * width + maximalNegativePriceBarWidth : 0) // Width for the price bar for positive range
      
        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .center)) {
            var fillColor = LinearGradient(gradient: Gradient(colors: [Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059), Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)]), startPoint: .topLeading, endPoint: .bottomTrailing)

            Path { path in
                if hourDataPoint.marketprice > 0 {
                    path.move(to: CGPoint(x: maximalNegativePriceBarWidth + singleBarSettings.verticalDividerLineWidth, y: startHeight + singleBarSettings.barHeightPadding))
                    path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - singleBarSettings.radius + singleBarSettings.verticalDividerLineWidth, y: startHeight + singleBarSettings.barHeightPadding + singleBarSettings.radius), radius: singleBarSettings.radius, startAngle: .degrees(270), delta: .degrees(180))
                    path.addLine(to: CGPoint(x: positivePriceBarWidth + singleBarSettings.verticalDividerLineWidth, y: startHeight + singleBarSettings.barHeightPadding + singleBarSettings.radius))
                    path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - singleBarSettings.radius + singleBarSettings.verticalDividerLineWidth, y: startHeight + height - singleBarSettings.barHeightPadding - singleBarSettings.radius), radius: singleBarSettings.radius, startAngle: .degrees(0), delta: .degrees(90))
                    path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth + singleBarSettings.verticalDividerLineWidth, y: startHeight + height - singleBarSettings.barHeightPadding))

                } else if hourDataPoint.marketprice < 0 {
                    let barStartWidth = maximalNegativePriceBarWidth - negativePriceBarWidth

                    path.move(to: CGPoint(x: barStartWidth, y: singleBarSettings.barHeightPadding))
                    path.addRelativeArc(center: CGPoint(x: barStartWidth + singleBarSettings.radius, y: singleBarSettings.radius + singleBarSettings.barHeightPadding), radius: singleBarSettings.radius, startAngle: .degrees(180), delta: .degrees(90))
                    path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: singleBarSettings.barHeightPadding))
                    path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: height - singleBarSettings.barHeightPadding))
                    path.addRelativeArc(center: CGPoint(x: barStartWidth + singleBarSettings.radius, y: height - singleBarSettings.barHeightPadding - singleBarSettings.radius), radius: singleBarSettings.radius, startAngle: .degrees(90), delta: .degrees(90))

                    fillColor = LinearGradient(gradient: Gradient(colors: [Color.green, Color.gray]), startPoint: .leading, endPoint: .trailing)
                }
            }
            .fill(fillColor)
            .shadow(radius: 3)

            if maximalNegativePriceBarWidth != 0 {
                Path { path in
                    let verticalDividerLineStartWidth = maximalNegativePriceBarWidth + (singleBarSettings.verticalDividerLineWidth / 2)

                    path.move(to: CGPoint(x: verticalDividerLineStartWidth, y: startHeight))
                    path.addLine(to: CGPoint(x: verticalDividerLineStartWidth, y: height + startHeight))
                }
                .strokedPath(StrokeStyle(lineWidth: singleBarSettings.verticalDividerLineWidth, lineCap: .square))
                .foregroundColor(Color.blue)
            }
//
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

            if currentSetting.setting!.pricesWithTaxIncluded {
                // With tax
                Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001 * 1.16)))!)
                    .font(.caption)
                    .position(x: 20, y: startHeight)

            } else if !currentSetting.setting!.pricesWithTaxIncluded {
                // Without tax
                Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001)))!)
                    .font(.caption)
                    .position(x: 20, y: startHeight + singleBarSettings.barHeightPadding)
            }
//
//            HStack(spacing: 5) {
//                Text(hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.startTimestamp / 1000))))
//                Text("-")
//                Text(hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.endTimestamp / 1000))))
//            }
//            .foregroundColor(Color.black)
//            .padding(.top, 1.5)
//            .padding(.bottom, 1.5)
//            .padding(.leading, 5)
//            .padding(.trailing, 5)
//            .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hue: 0.6111, saturation: 0.0276, brightness: 0.8510)]), startPoint: .topLeading, endPoint: .bottomTrailing))
//            .cornerRadius(4)
//            .shadow(radius: 2)
//            .padding(.trailing, 25)
//            .padding(.leading, 10)
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
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
            path.move(to: CGPoint(x: 0, y: startHeight + singleBarSettings.barHeightPadding + (height / 2)))
            path.addLine(to: CGPoint(x: width - 20, y: startHeight + singleBarSettings.barHeightPadding + (height / 2)))
        }
        .strokedPath(StrokeStyle(lineWidth: singleBarSettings.horizontalDividerLineHeight, lineCap: .round))
    }
}

class SingleBarSettings {
    let radius = CGFloat(4)
    
    let horizontalDividerLineHeight = CGFloat(5)
    let verticalDividerLineWidth = CGFloat(7)
    
    let barHeightPadding = CGFloat(4) // Padding kept to the top and to the bottom
    
    var centFormatter: NumberFormatter
    var hourFormatter: DateFormatter
        
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
    
    let singleBarSettings = SingleBarSettings()
    
    var body: some View {
        GeometryReader { geometry in
            makeView(geometry)
        }
    }
    
    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let singleHeight = height / 24
        
        let graphDragGesture = DragGesture()
            .onChanged { location in
                let locationHeight = location.location.y
                
                if (currentPointerHourHeight == nil) || !(locationHeight == currentPointerHourHeight!.1) {
                    for hour in graphHourPointData {
                        if locationHeight >= hour.1 && locationHeight <= (hour.1 + singleHeight) {
                            withAnimation {
                                currentPointerHourHeight = (hour.0, hour.1)
                            }
                        }
                    }
                }
            }
            .onEnded {_ in
                withAnimation {
                    currentPointerHourHeight = nil
                }
            }
        
        return ZStack {
            ForEach(graphHourPointData, id: \.0.startTimestamp) { hourPoint in
                EnergyPriceSingleBar(
                    singleBarSettings: singleBarSettings,
                    width: width,
                    height: singleHeight,
                    startHeight: hourPoint.1,
                    hourDataPoint: hourPoint.0,
                    minPrice: awattarData.energyData!.awattar.minPrice,
                    maxPrice: awattarData.energyData!.awattar.maxPrice)
                
                if currentPointerHourHeight != nil {
                    EnergyPriceSingleBarPointerHighlighter(
                        singleBarSettings: singleBarSettings,
                        width: width,
                        height: singleHeight,
                        startHeight: currentPointerHourHeight!.1,
                        hourDataPoint: currentPointerHourHeight!.0)
                        .transition(.opacity)
                        .animation(.linear(duration: 0.2))
                }
            }
        }
        .gesture(graphDragGesture)
        .onAppear {
            var currentHeight: CGFloat = 0
            var tomorrowMidnight = Calendar.current.startOfDay(for: Date()) // Debugging: When printing dates they are shown in UTC format
            tomorrowMidnight.addTimeInterval(86400) // Add one day
            
            for hourPoint in awattarData.energyData!.awattar.prices {
                if !(Date(timeIntervalSince1970: TimeInterval(hourPoint.startTimestamp / 1000)) >= tomorrowMidnight) {
                    graphHourPointData.append((hourPoint, currentHeight))
                    currentHeight += singleHeight
                } else {
                    break
                }
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
