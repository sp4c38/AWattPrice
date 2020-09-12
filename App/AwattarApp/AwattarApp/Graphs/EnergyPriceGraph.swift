//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

struct EnergyPriceGraph: View {
    // Displays a graph for the price of energy for a certain time
    var awattarDataPoint: AwattarDataPoint
    
    var minPrice: Float?
    var maxPrice: Float?
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let radius = CGFloat(4)
            let dividerLineWidth = CGFloat(5)
            
            let maximalNegativePriceBarWidth = (
                (minPrice != nil && !(minPrice == 0))
                    ? CGFloat(abs(minPrice!) / (abs(minPrice!) + abs(maxPrice!))) * width : 0) // Width of most negative price bar
            
            let negativePriceBarWidth = (
                (minPrice != nil && !(minPrice == 0))
                    ? CGFloat(abs(awattarDataPoint.marketprice) / (abs(minPrice!) + abs(maxPrice!))) * width : 0) // Width for the price bar for negative range
            
            let positivePriceBarWidth = (
                (maxPrice != nil)
                    ? CGFloat(abs(awattarDataPoint.marketprice) / (abs(minPrice!) + abs(maxPrice!))) * width + maximalNegativePriceBarWidth : 0) // Width for the price bar for positive range
          
            HStack(spacing: 0) {
                var fillColor = Color.orange
                Path { path in
                    if awattarDataPoint.marketprice > 0 {
                        path.move(to: CGPoint(x: maximalNegativePriceBarWidth, y: 0))
                        path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - radius, y: radius), radius: radius, startAngle: .degrees(270), delta: .degrees(180))
                        path.addLine(to: CGPoint(x: positivePriceBarWidth, y: radius))
                        path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - radius, y: height - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
                        path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: height))
                        
                    } else if awattarDataPoint.marketprice < 0 {
                        let barStartWidth = maximalNegativePriceBarWidth - negativePriceBarWidth
                        path.move(to: CGPoint(x: barStartWidth, y: 0))
                        path.addRelativeArc(center: CGPoint(x: barStartWidth + radius, y: radius), radius: radius, startAngle: .degrees(180), delta: .degrees(90))
                        path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: 0))
                        path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: height))
                        path.addRelativeArc(center: CGPoint(x: barStartWidth + radius, y: height - radius), radius: radius, startAngle: .degrees(90), delta: .degrees(90))
                        
                        fillColor = Color.green
                    }
                }
                .fill(fillColor)
                
                Path { path in
                    let dividerLineNegativePriceBar = (width - (width - maximalNegativePriceBarWidth)) - (width / 2) - (dividerLineWidth / 2)
                    
                    path.move(to: CGPoint(x: dividerLineNegativePriceBar, y: 0))
                    path.addLine(to: CGPoint(x: dividerLineNegativePriceBar + dividerLineWidth, y: 0))
                    path.addLine(to: CGPoint(x: dividerLineNegativePriceBar + dividerLineWidth, y: height))
                    path.addLine(to: CGPoint(x: dividerLineNegativePriceBar, y: height))
                }
                .fill(Color.red)
            }
        }
    }
}

struct EnergyPriceGraph_Previews: PreviewProvider {
    static var previews: some View {
        EnergyPriceGraph(awattarDataPoint: AwattarDataPoint(startTimestamp: 1599516000000, endTimestamp: 1599519600000, marketprice: -20, unit: ["Eur / MWh", "Eur / kWh"]), minPrice: -30, maxPrice: 30)
            .frame(height: 60)
    }
}
