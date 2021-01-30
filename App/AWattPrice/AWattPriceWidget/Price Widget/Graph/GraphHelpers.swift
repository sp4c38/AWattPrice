//
//  GraphHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

class GraphPoint {
    let height: CGFloat
    let marketprice: Double
    
    init(_ pointMarketprice: Double, _ pointHeight: CGFloat) {
        height = pointHeight
        marketprice = pointMarketprice
    }
}

class GraphData {
    let allWidth: CGFloat
    let allHeight: CGFloat
    
    var points = [GraphPoint]()
    var pointWidth: CGFloat? = nil
    
    init(_ width: CGFloat, _ height: CGFloat) {
        allWidth = width
        allHeight = height
    }
    
    func setValuesAfterDefinitions() {
        pointWidth = allWidth / CGFloat(points.count)
    }
}

func createGraphData(
    _ energyData: EnergyData, _ geoProxy: GeometryProxy
) -> GraphData {
    let maxHeight = geoProxy.size.height
    let graphData = GraphData(geoProxy.size.width, maxHeight)
    
    for point in energyData.prices {
        let pointHeight = (
            CGFloat(point.marketprice / energyData.maxPrice) * maxHeight
        )
        
        let graphPoint = GraphPoint(point.marketprice, pointHeight)
        graphData.points.append(graphPoint)
    }
    
    graphData.setValuesAfterDefinitions()
    return graphData
}
