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
            
            let maximalNegativePriceBarWidth = (
                (minPrice != nil && !(minPrice == 0))
                    ? CGFloat(abs(minPrice!) / (abs(minPrice!) + abs(maxPrice!))) * width : 0) // Width of most negative price bar
            
            
            let negativePriceBarWidth = (
                (minPrice != nil && !(minPrice == 0))
                    ? CGFloat(abs(awattarDataPoint.marketprice) / (abs(minPrice!) + abs(maxPrice!))) * width : 0) // Width for the price bar for negative range
            
            let positivePriceBarWidth = (
                (maxPrice != nil)
                    ? CGFloat(abs(awattarDataPoint.marketprice) / (abs(minPrice!) + abs(maxPrice!))) * width + maximalNegativePriceBarWidth : 0) // Width for the price bar for positive range
          
            HStack {
                var fillColor = Color.red
                Path { path in
                    if awattarDataPoint.marketprice > 0 {
                        path.move(to: CGPoint(x: maximalNegativePriceBarWidth, y: 0))
                        path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - radius, y: radius), radius: radius, startAngle: .degrees(270), delta: .degrees(180))
                        path.addLine(to: CGPoint(x: positivePriceBarWidth, y: radius))
                        path.addRelativeArc(center: CGPoint(x: positivePriceBarWidth - radius, y: height - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
                        path.addLine(to: CGPoint(x: maximalNegativePriceBarWidth, y: height))
                        
                    } else if awattarDataPoint.marketprice < 0 {
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: negativePriceBarWidth, y: 0))
                        path.addLine(to: CGPoint(x: negativePriceBarWidth, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: 0, y: 0))
                        fillColor = Color.green
                    }
                }
                .fill(fillColor)
            }
        }
    }
}

struct EnergyPriceGraph_Previews: PreviewProvider {
    static var previews: some View {
        EnergyPriceGraph(awattarDataPoint: AwattarDataPoint(startTimestamp: 1599516000000, endTimestamp: 1599519600000, marketprice: 60, unit: ["Eur / MWh", "Eur / kWh"]), minPrice: -10, maxPrice: 60)
            .frame(height: 60)
    }
}
