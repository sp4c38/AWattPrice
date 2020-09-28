//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

struct EnergyPriceGraph: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    
    var awattarDataPoint: EnergyPricePoint
    
    var minPrice: Float?
    var maxPrice: Float?
    
    var numberFormatter: NumberFormatter
    
    init(awattarDataPoint: EnergyPricePoint, minPrice: Float?, maxPrice: Float?) {
        self.awattarDataPoint = awattarDataPoint
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        
        numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = Locale(identifier: "de_DE")
        numberFormatter.currencySymbol = "ct"
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let radius = CGFloat(4)
            
            let horizontalDividerLineHeight = CGFloat(5)
            let verticalDividerLineWidth = CGFloat(3)
            
            let barHeightPadding = CGFloat(3) // Padding kept to the top and to the bottom
            
            let maximalNegativePriceBarWidth = (
                (minPrice != nil && !(minPrice == 0))
                    ? CGFloat(abs(minPrice!) / (abs(minPrice!) + abs(maxPrice!))) * width : 0) // Width of most negative price bar
            
            let negativePriceBarWidth = (
                (minPrice != nil && !(minPrice == 0))
                    ? CGFloat(abs(awattarDataPoint.marketprice) / (abs(minPrice!) + abs(maxPrice!))) * width : 0) // Width for the price bar for negative range
            
            let positivePriceBarWidth = (
                (maxPrice != nil)
                    ? CGFloat(abs(awattarDataPoint.marketprice) / (abs(minPrice!) + abs(maxPrice!))) * width + maximalNegativePriceBarWidth : 0) // Width for the price bar for positive range
          
            ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
                var fillColor = LinearGradient(gradient: Gradient(colors: [Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059), Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)]), startPoint: .leading, endPoint: .trailing)
                
                Path { path in
                    if awattarDataPoint.marketprice > 0 {
                        path.move(to: CGPoint(x: maximalNegativePriceBarWidth, y: barHeightPadding))
                        path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - radius, y: radius + barHeightPadding), radius: radius, startAngle: .degrees(270), delta: .degrees(180))
                        path.addLine(to: CGPoint(x: positivePriceBarWidth, y: radius + barHeightPadding))
                        path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - radius, y: height - barHeightPadding - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
                        path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: height - barHeightPadding))

                    } else if awattarDataPoint.marketprice < 0 {
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

                Path { path in
                    let verticalDividerLineDeltaWidth = maximalNegativePriceBarWidth - (verticalDividerLineWidth / 2)

                    path.move(to: CGPoint(x: verticalDividerLineDeltaWidth, y: 0))
                    path.addLine(to: CGPoint(x: verticalDividerLineDeltaWidth + verticalDividerLineWidth, y: 0))
                    path.addLine(to: CGPoint(x: verticalDividerLineDeltaWidth + verticalDividerLineWidth, y: height))
                    path.addLine(to: CGPoint(x: verticalDividerLineDeltaWidth, y: height))
                }
                .fill(Color.blue)
                .shadow(radius: 3)

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
                    Text(numberFormatter.string(from: NSNumber(value: (awattarDataPoint.marketprice * 100 * 0.001 * 1.16)))!)
                        .font(.caption)
                        .padding(.leading, 10)

                } else if !currentSetting.setting!.pricesWithTaxIncluded {
                    // Without tax
                    Text(numberFormatter.string(from: NSNumber(value: (awattarDataPoint.marketprice * 100 * 0.001)))!)
                        .font(.caption)
                        .padding(.leading, 10)
                }
            }

        }
    }
}

struct EnergyPriceGraph_Previews: PreviewProvider {
    static var previews: some View {
        EnergyPriceGraph(awattarDataPoint: EnergyPricePoint(startTimestamp: 1599516000000, endTimestamp: 1599519600000, marketprice: -20), minPrice: -30, maxPrice: 30)
            .frame(height: 60)
    }
}
