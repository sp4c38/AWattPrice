//
//  GraphHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

class GraphPoint {
    let startX: CGFloat
    let height: CGFloat
    let marketprice: Double
    
    init(_ pointStartX: CGFloat, _ pointHeight: CGFloat, _ pointMarketprice: Double) {
        startX = pointStartX
        height = pointHeight
        marketprice = pointMarketprice
    }
}

class GraphData {
    /* Strictly speaking allWidth and allHeight aren't needed to be able to
     create the graph. They get stored for reference if needed elsewhere.
    */
    let allWidth: CGFloat
    let allHeight: CGFloat
    
    var points = [GraphPoint]()
    var pointWidth: CGFloat
    
    init(_ width: CGFloat, _ height: CGFloat, _ pointWidth: CGFloat) {
        allWidth = width
        allHeight = height
        self.pointWidth = pointWidth
    }
}

func createGraphData(
    _ energyData: EnergyData, _ geoProxy: GeometryProxy
) -> GraphData {
    let maxWidth = geoProxy.size.width
    let maxHeight = geoProxy.size.height
    let pointWidth = maxWidth / CGFloat(energyData.prices.count)
    
    let graphData = GraphData(geoProxy.size.width, maxHeight, pointWidth)
    
    var currentStartX: CGFloat = 0
    for point in energyData.prices {
        let pointHeight = (
            CGFloat(point.marketprice / energyData.maxPrice) * maxHeight
        )
        
        let graphPoint = GraphPoint(currentStartX, pointHeight, point.marketprice)
        graphData.points.append(graphPoint)
        
        currentStartX += graphData.pointWidth
    }
    
    return graphData
}
