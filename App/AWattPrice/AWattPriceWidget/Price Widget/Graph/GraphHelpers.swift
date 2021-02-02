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
    
    init(startX pointStartX: CGFloat, startY pointStartY: CGFloat, height pointHeight: CGFloat,
         marketprice pointMarketprice: Double) {
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
    let startX: CGFloat
    
    init(content startTime: Date, startX: CGFloat) {
        let hour = Calendar.current.component(.hour, from: startTime)
        content = String(hour)
        self.startX = startX
    }
}

enum GraphTextPadding {
    case bottom
}
enum GraphTextOverlapPadding {
    case leading, trailing
}

enum GraphPadding {
    case top, bottom, leading, trailing
}

class GraphProperties {
    /* Store in an extra class to make it easier to only parse the properties, without
     parsing all GraphPoints.
    */
    
    var allWidth: CGFloat
    var allHeight: CGFloat
    
    // Add point text each X points. Set to 1 to add text for each bar.
    var textRepeating: Int
    var textPaddings: [GraphTextPadding: CGFloat] = [.bottom: 0] // Paddings to later apply to each text element
    var textOverlapPaddings: [GraphTextOverlapPadding: CGFloat] = [
        .leading: 0, .trailing: 0
    ] // Paddings to apply to text which is exactly at start (leading) or end (trailing) of the graph.
    
    var startX: CGFloat
    var endX: CGFloat
    var startY: CGFloat
    var endY: CGFloat
    
    var pointWidth: CGFloat
    var pointSpacing: CGFloat
    
    init(_ width: CGFloat, _ height: CGFloat, numberOfPoints: Int,
         textRepeating: Int, pointSpacing: CGFloat) {
        allWidth = width
        allHeight = height
        
        self.textRepeating = textRepeating
        
        startX = 0
        endX = width
        startY = 0
        endY = height
        
        pointWidth = allWidth / CGFloat(numberOfPoints) // Perform only after paddings were applied
        self.pointSpacing = pointSpacing
    }
    
    func addPaddings(
        textPaddings: [GraphTextPadding: CGFloat]?,
        textOverlapPaddings: [GraphTextOverlapPadding: CGFloat]?,
        graphPaddings: [GraphPadding: CGFloat]?
    ) {
        makeTextPaddings(textPaddings)
        makeTextOverlapPaddings(textOverlapPaddings)
        applyGraphPaddings(graphPaddings)
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

fileprivate func getPointStartX(_ pointIndex: Int, _ graphProperties: GraphProperties) -> CGFloat {
    let startX = (
        graphProperties.startX + (CGFloat(pointIndex) * graphProperties.pointWidth)
    )
    return startX
}

fileprivate func getGraphPoint(
    _ pointIndex: Int,
    _ point: EnergyPricePoint,
    _ graphData: GraphData,
    _ maxPrice: Double
) -> GraphPoint {
    let pointStartX = getPointStartX(pointIndex, graphData.properties)
    
    let pointHeight = (
        CGFloat(point.marketprice / maxPrice) *
            graphData.properties.allHeight
    )
    let pointStartY = graphData.properties.endY - pointHeight
    
    let graphPoint = GraphPoint(
        startX: pointStartX,
        startY: pointStartY,
        height: pointHeight,
        marketprice: point.marketprice
    )
    return graphPoint
}

fileprivate func getTextStartX(
    _ pointIndex: Int,
    _ graphProperties: GraphProperties
) -> CGFloat {
    let startX = (
        graphProperties.startX // Start paddings
            + (CGFloat(pointIndex) * graphProperties.pointWidth)
    )
    return startX
}

fileprivate func getGraphText(
    _ pointIndex: Int,
    _ point: EnergyPricePoint,
    _ graphData: GraphData
) -> GraphText? {
    let textRepeating = graphData.properties.textRepeating
    
    let pointStartHour = Calendar.current.component(.hour, from: point.startTimestamp)
    // Only add text each Xth point. Subtract one to comply with zero-indexing.
    if textRepeating > 1 {
        guard pointStartHour % textRepeating == 0 else { return nil }
    }
    
    let startX = getTextStartX(pointIndex, graphData.properties)
    
    let graphText = GraphText(
        content: point.startTimestamp,
        startX: startX
    )
    
    return graphText
}

func getTextRepeating(with numberOfPoints: Int) -> Int {
    return 6
}

func getPointSpacing(with numberOfPoints: Int) -> CGFloat {
    var spacing: CGFloat = 0
    
    if numberOfPoints < 10 {
        spacing = 1.8
    } else if numberOfPoints >= 10, numberOfPoints < 25 {
        spacing = 1.5
    } else {
        spacing = 0.8
    }
    
    return spacing
}

func createGraphData(
    _ energyData: EnergyData, _ geoProxy: GeometryProxy
) -> GraphData {
    let maxWidth = geoProxy.size.width
    let maxHeight = geoProxy.size.height
    
    let numberOfPoints = energyData.prices.count
    let graphProperties = GraphProperties(
        maxWidth, maxHeight,
        numberOfPoints: numberOfPoints,
        textRepeating: getTextRepeating(with: numberOfPoints),
        pointSpacing: getPointSpacing(with: numberOfPoints)
    )
    graphProperties.addPaddings(
        textPaddings: [.bottom: 10],
        textOverlapPaddings: [.leading: 5, .trailing: 3],
        graphPaddings: [.top: 25]
    )
    let graphData = GraphData(graphProperties)
    
    var indexCounter = 0
    for point in energyData.prices {
        let graphPoint = getGraphPoint(
            indexCounter, point, graphData, energyData.maxPrice
        )
        graphData.points.append(graphPoint)
        
        if let graphText = getGraphText(
            indexCounter, point, graphData
        ) {
            graphData.texts.append(graphText)
        }
        
        indexCounter += 1
    }
    return graphData
}
