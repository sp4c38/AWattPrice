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
    let start: Date
    let marketprice: Double
    let isNegative: Bool
    
    init(
        _ pointStartX: CGFloat, _ pointHeight: CGFloat,
        _ pointStart: Date, _ pointMarketprice: Double) {
        
        startX = pointStartX
        height = pointHeight
        start = pointStart
        marketprice = pointMarketprice
        
        if pointMarketprice < 0 {
            isNegative = true
        } else {
            isNegative = false
        }
    }
}

enum GraphPaddings {
    case top, bottom, leading, trailing
}

class GraphProperties {
    /* Store in an extra class to make it easier to only parse the properties, without
     parsing all GraphPoints.
    */
    
    var allWidth: CGFloat
    var allHeight: CGFloat
    
    var startX: CGFloat
    var endX: CGFloat
    var startY: CGFloat
    var endY: CGFloat
    let pointWidth: CGFloat
    
    init(_ width: CGFloat, _ height: CGFloat,
         _ pointWidth: CGFloat, paddings: [GraphPaddings: CGFloat]?) {
        
        allWidth = width
        allHeight = height
        self.pointWidth = pointWidth
        
        startX = 0
        endX = width
        startY = 0
        endY = height
        applyPaddings(paddings)
    }
}

extension GraphProperties {
    private func applyPaddings(_ paddings: [GraphPaddings: CGFloat]?) {
        if let paddings = paddings {
            if paddings.keys.contains(.top) {
                startY += paddings[.top]!
                allHeight -= paddings[.top]!
            }
            if paddings.keys.contains(.bottom) {
                endY -= paddings[.bottom]!
                allHeight -= paddings[.bottom]!
            }
            if paddings.keys.contains(.leading) {
                startX += paddings[.leading]!
                allWidth -= paddings[.leading]!
            }
            if paddings.keys.contains(.trailing) {
                endX -= paddings[.trailing]!
                allWidth -= paddings[.trailing]!
            }
        }
    }
}

class GraphData {
    /* Strictly speaking allWidth and allHeight aren't needed to be able to
     create the graph. They get stored for reference if needed elsewhere.
    */
    var properties: GraphProperties
    var points = [GraphPoint]()
    
    init(_ graphProperties: GraphProperties) {
        properties = graphProperties
    }
}

func createGraphData(
    _ energyData: EnergyData, _ geoProxy: GeometryProxy
) -> GraphData {
    let maxWidth = geoProxy.size.width
    let maxHeight = geoProxy.size.height
    let pointWidth = maxWidth / CGFloat(energyData.prices.count)
    
    let graphProperties = GraphProperties(
        geoProxy.size.width, maxHeight, pointWidth,
        paddings: [.top: 16]
    )
    let graphData = GraphData(graphProperties)
    
    var currentStartX: CGFloat = 0
    for point in energyData.prices {
        let pointHeight = (
            CGFloat(point.marketprice / energyData.maxPrice) *
                graphData.properties.allHeight
        )
        
        let graphPoint = GraphPoint(
            currentStartX, pointHeight, point.startTimestamp, point.marketprice
        )
        graphData.points.append(graphPoint)
        
        currentStartX += graphData.properties.pointWidth
    }
    
    return graphData
}
