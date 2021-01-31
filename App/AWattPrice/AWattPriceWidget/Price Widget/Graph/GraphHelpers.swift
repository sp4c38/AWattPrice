//
//  GraphHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

class GraphPoint {
    let startX: CGFloat
    let startY: CGFloat
    let height: CGFloat
    
    let isNegative: Bool
    
    init(_ pointStartX: CGFloat, _ pointStartY: CGFloat, _ pointHeight: CGFloat,
         _ pointMarketprice: Double) {
        startX = pointStartX
        startY = pointStartY
        height = pointHeight
        
        if pointMarketprice < 0 {
            isNegative = true
        } else {
            isNegative = false
        }
    }
}

class GraphText {
    let content: String
    let centerX: CGFloat
    
    init(content startTime: Date, centerX: CGFloat) {
        let hour = Calendar.current.component(.hour, from: startTime)
        content = String(hour)
        self.centerX = centerX
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
    var pointWidth: CGFloat = 0
    
    init(_ width: CGFloat, _ height: CGFloat, numberOfPoints: Int,
         paddings: [GraphPaddings: CGFloat]?) {
        allWidth = width
        allHeight = height
        
        startX = 0
        endX = width
        startY = 0
        endY = height
        applyPaddings(paddings)
        pointWidth = allWidth / CGFloat(numberOfPoints) // Perform only after paddings were applied
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
    var texts = [GraphText]()
    
    init(_ graphProperties: GraphProperties) {
        properties = graphProperties
    }
}

fileprivate func getGraphPoint(
    _ pointIndex: Int,
    _ graphData: GraphData
    _ point: EnergyPricePoint,
    _ maxPrice: Double
) -> GraphPoint {
    let currentStartX = (
        graphData.properties.startX + (CGFloat(pointIndex) * graphData.properties.pointWidth)
    )
    
    let pointHeight = (
        CGFloat(point.marketprice / maxPrice) *
            graphData.properties.allHeight
    )
    
    let pointStartY = graphData.properties.endY - pointHeight
    
    let graphPoint = GraphPoint(
        currentStartX, pointStartY, pointHeight,
        point.marketprice
    )
    return graphPoint
}

func createGraphData(
    _ energyData: EnergyData, _ geoProxy: GeometryProxy
) -> GraphData {
    let maxWidth = geoProxy.size.width
    let maxHeight = geoProxy.size.height
    
    let graphProperties = GraphProperties(
        maxWidth, maxHeight,
        numberOfPoints: energyData.prices.count,
        paddings: [.top: 16]
    )
    let graphData = GraphData(graphProperties)
    
    var indexCounter = 0
    for point in energyData.prices {
        let graphPoint = getGraphPoint(
            indexCounter, graphData, point, energyData.maxPrice
        )
        graphData.points.append(graphPoint)
        
        
        indexCounter += 1
    }
    
    return graphData
}
