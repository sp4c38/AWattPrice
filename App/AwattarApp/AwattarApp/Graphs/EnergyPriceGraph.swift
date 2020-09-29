//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

struct EnergyPriceSingleBar: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    
    let hourFormatter: DateFormatter
    let centFormatter: NumberFormatter
    let width: CGFloat
    let height: CGFloat
    let hourDataPoint: EnergyPricePoint
    let minPrice: Float
    let maxPrice: Float
    
    init(hourFormatter: DateFormatter,
         centFormatter: NumberFormatter,
         width: CGFloat,
         height: CGFloat,
         hourDataPoint: EnergyPricePoint,
         minPrice: Float,
         maxPrice: Float) {
        
        self.hourFormatter = hourFormatter
        self.centFormatter = centFormatter
        self.width = width
        self.height = height
        self.hourDataPoint = hourDataPoint
        self.minPrice = minPrice
        self.maxPrice = maxPrice
    }
    
    var body: some View {
        let radius = CGFloat(4)
        
        let horizontalDividerLineHeight = CGFloat(5)
        let verticalDividerLineWidth = CGFloat(3)
        
        let barHeightPadding = CGFloat(0) // Padding kept to the top and to the bottom
        
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
            ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
                var fillColor = LinearGradient(gradient: Gradient(colors: [Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059), Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                
                Path { path in
                    if hourDataPoint.marketprice > 0 {
                        path.move(to: CGPoint(x: maximalNegativePriceBarWidth + verticalDividerLineWidth, y: barHeightPadding))
                        path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - radius + verticalDividerLineWidth, y: radius + barHeightPadding), radius: radius, startAngle: .degrees(270), delta: .degrees(180))
                        path.addLine(to: CGPoint(x: positivePriceBarWidth + verticalDividerLineWidth, y: radius + barHeightPadding))
                        path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - radius + verticalDividerLineWidth, y: height - barHeightPadding - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
                        path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth + verticalDividerLineWidth, y: height - barHeightPadding))

                    } else if hourDataPoint.marketprice < 0 {
                        let barStartWidth = maximalNegativePriceBarWidth - negativePriceBarWidth

                        path.move(to: CGPoint(x: barStartWidth, y: barHeightPadding))
                        path.addRelativeArc(center: CGPoint(x: barStartWidth + radius, y: radius + barHeightPadding), radius: radius, startAngle: .degrees(180), delta: .degrees(90))
                        path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: barHeightPadding))
                        path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: height - barHeightPadding))
                        path.addRelativeArc(center: CGPoint(x: barStartWidth + radius, y: height - barHeightPadding - radius), radius: radius, startAngle: .degrees(90), delta: .degrees(90))

                        fillColor = LinearGradient(gradient: Gradient(colors: [Color.green, Color.gray]), startPoint: .leading, endPoint: .trailing)
                    }
                }
                .fill(fillColor)
                .shadow(radius: 3)

                Path { path in
                    let verticalDividerLineStartWidth = (maximalNegativePriceBarWidth != 0) ? (maximalNegativePriceBarWidth - (verticalDividerLineWidth / 2)) : 0

                    path.move(to: CGPoint(x: verticalDividerLineStartWidth, y: 0))
                    path.addLine(to: CGPoint(x: verticalDividerLineStartWidth + verticalDividerLineWidth, y: 0))
                    path.addLine(to: CGPoint(x: verticalDividerLineStartWidth + verticalDividerLineWidth, y: height))
                    path.addLine(to: CGPoint(x: verticalDividerLineStartWidth, y: height))
                }
                .fill(Color.blue)

                if false {
                    let horizontalLineStartHeight = (height / 2) - (horizontalDividerLineHeight / 2) + barHeightPadding

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: horizontalLineStartHeight))
                        path.addLine(to: CGPoint(x: width, y: horizontalLineStartHeight))
                        path.addLine(to: CGPoint(x: width, y: horizontalLineStartHeight + horizontalDividerLineHeight / 2))
                        path.addLine(to: CGPoint(x: 0, y: horizontalLineStartHeight + horizontalDividerLineHeight / 2))
                        path.addLine(to: CGPoint(x: 0, y: horizontalLineStartHeight))
                    }
                    .fill(Color.red)
                }

                if currentSetting.setting!.pricesWithTaxIncluded {
                    // With tax
                    Text(centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001 * 1.16)))!)
                        .font(.caption)
                        .padding(.leading, 10)

                } else if !currentSetting.setting!.pricesWithTaxIncluded {
                    // Without tax
                    Text(centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001)))!)
                        .font(.caption)
                        .padding(.leading, 10)
                }
           }

            HStack(spacing: 5) {
                Text(hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.startTimestamp / 1000))))
                Text("-")
                Text(hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.endTimestamp / 1000))))
            }
            .foregroundColor(Color.black)
            .padding(.top, 1.5)
            .padding(.bottom, 1.5)
            .padding(.leading, 5)
            .padding(.trailing, 5)
            .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hue: 0.6111, saturation: 0.0276, brightness: 0.8510)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(4)
            .shadow(radius: 2)
            .padding(.trailing, 25)
            .padding(.leading, 10)
        }
        .border(Color.black, width: 2)
        .padding(.leading, 10)
        .padding(.trailing, 10)
    }
}

struct EnergyPriceGraph: View {
    @EnvironmentObject var awattarData: AwattarData
    
    @State var graphHourPointData = [(EnergyPricePoint, CGFloat)]()
    @State var currentPointHeight: CGFloat? = nil
    
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
    
    var body: some View {
        GeometryReader { geometry in
            makeView(geometry)
        }
    }
    
    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let singleHeight = height / CGFloat(awattarData.energyData!.awattar.prices.count)
        
        let graphDragGesture = DragGesture()
            .onChanged { location in
                print(location.location)
                currentPointHeight = location.location.y
            }
            .onEnded {_ in
                currentPointHeight = nil
            }
        
        return ZStack {
            VStack(spacing: 0) {
                ForEach(graphHourPointData, id: \.0.startTimestamp) { hourPoint in
                    EnergyPriceSingleBar(
                        hourFormatter: hourFormatter,
                        centFormatter: centFormatter,
                        width: width,
                        height: singleHeight,
                        hourDataPoint: hourPoint.0,
                        minPrice: awattarData.energyData!.awattar.minPrice,
                        maxPrice: awattarData.energyData!.awattar.maxPrice)
                }
            }
            .gesture(graphDragGesture)
            
            if currentPointHeight != nil {
                Text("Here")
                    .position(x: 0, y: currentPointHeight!)
            }
        }
        .onAppear {
            var currentHeight: CGFloat = 0
            for hourPoint in awattarData.energyData!.awattar.prices {
                graphHourPointData.append((hourPoint, currentHeight))
                currentHeight += singleHeight
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
