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
    let position: [GraphTextPosition: Bool]
    
    init(content startTime: Date, startX: CGFloat, position: [GraphTextPosition: Bool]) {
        let hour = Calendar.current.component(.hour, from: startTime)
        content = String(hour)
        self.startX = startX
        self.position = position
    }
}

enum GraphTextPaddings {
    case bottom
}
enum GraphFirstLastTextPaddings {
    case leading, trailing
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
    
    // Add point text each X points. Set to 1 to add text for each bar.
    var textRepeating: Int
    var textPaddings: [GraphTextPaddings: CGFloat] = [.bottom: 0] // Paddings to later apply to each text element
    var firstLastTextPaddings: [GraphFirstLastTextPaddings: CGFloat] = [
        .leading: 0, .trailing: 0
    ] // Paddings to later apply to the first and last texts
    
    var startX: CGFloat
    var endX: CGFloat
    var startY: CGFloat
    var endY: CGFloat
    var pointWidth: CGFloat = 0
    
    init(_ width: CGFloat, _ height: CGFloat, numberOfPoints: Int,
         textRepeating: Int) {
        allWidth = width
        allHeight = height
        
        self.textRepeating = textRepeating
        
        startX = 0
        endX = width
        startY = 0
        endY = height
        
        pointWidth = allWidth / CGFloat(numberOfPoints) // Perform only after paddings were applied
    }
    
    func addPaddings(
        textPaddings: [GraphTextPaddings: CGFloat]?,
        firstLastTextPaddings: [GraphFirstLastTextPaddings: CGFloat]?,
        graphPaddings: [GraphPaddings: CGFloat]?
    ) {
        makeTextPaddings(textPaddings)
        makeFirstLastTextPaddings(firstLastTextPaddings)
        applyGraphPaddings(graphPaddings)
    }
}

extension GraphProperties {
    private func makeTextPaddings(_ paddings: [GraphTextPaddings: CGFloat]?) {
        if let paddings = paddings {
            if paddings.keys.contains(.bottom) {
                textPaddings[.bottom] = paddings[.bottom]!
            }
        }
    }
    
    private func makeFirstLastTextPaddings(_ paddings: [GraphFirstLastTextPaddings: CGFloat]?) {
        if let paddings = paddings {
            if paddings.keys.contains(.leading) {
                firstLastTextPaddings[.leading] = paddings[.leading]!
            }
            if paddings.keys.contains(.trailing) {
                firstLastTextPaddings[.trailing] = paddings[.trailing]!
            }
        }
    }
    
    private func applyGraphPaddings(_ paddings: [GraphPaddings: CGFloat]?) {
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
    _ graphProperties: GraphProperties,
    _ position: [GraphTextPosition: Bool]
) -> CGFloat {
    var textLeadingPadding: CGFloat = 0
    if position[.first] == true {
        textLeadingPadding = graphProperties.firstLastTextPaddings[.leading]!
    }
    
    let startX = (
        graphProperties.startX + textLeadingPadding // Start paddings
            + (CGFloat(pointIndex) * graphProperties.pointWidth)
    )
    return startX
}

enum GraphTextPosition {
    case first, last
}

fileprivate func resolveGraphTextPosition(_ textPositions: [GraphTextPosition: Bool]?) -> [GraphTextPosition: Bool] {
    var defaultPosition: [GraphTextPosition: Bool] = [.first: false, .last: false]
    if let positions = textPositions {
        if positions.keys.contains(.first) {
            defaultPosition[.first] = positions[.first]
        }
        if positions.keys.contains(.last) {
            defaultPosition[.last] = positions[.last]
        }
    }
    return defaultPosition
}

fileprivate func getGraphText(
    _ pointIndex: Int,
    _ point: EnergyPricePoint,
    _ graphData: GraphData,
    positions: [GraphTextPosition: Bool]?
) -> GraphText? {
    let textRepeating = graphData.properties.textRepeating
    // Add text each Xth point. Subtract one to comply with zero-indexing.
    if textRepeating > 1 {
        guard pointIndex % (textRepeating - 1) == 0 else { return nil }
    }
    let textPosition = resolveGraphTextPosition(positions)
    let startX = getTextStartX(pointIndex, graphData.properties, textPosition)
    
    let graphText = GraphText(
        content: point.startTimestamp,
        startX: startX,
        position: textPosition
    )
    
    return graphText
}

func createGraphData(
    _ energyData: EnergyData, _ geoProxy: GeometryProxy
) -> GraphData {
    let maxWidth = geoProxy.size.width
    let maxHeight = geoProxy.size.height
    
    let graphProperties = GraphProperties(
        maxWidth, maxHeight,
        numberOfPoints: energyData.prices.count,
        textRepeating: 6
    )
    graphProperties.addPaddings(
        textPaddings: [.bottom: 10],
        firstLastTextPaddings: [.leading: 16, .trailing: 0], // Extra paddings for the first and last text
        graphPaddings: [.top: 25]
    )
    let graphData = GraphData(graphProperties)
    
    var indexCounter = 0
    for point in energyData.prices {
        let graphPoint = getGraphPoint(
            indexCounter, point, graphData, energyData.maxPrice
        )
        graphData.points.append(graphPoint)
        
        let isFirst = indexCounter == 0
        let isLast = indexCounter == (energyData.prices.count - 1)
        if let graphText = getGraphText(
            indexCounter, point, graphData,
            positions: [.first: isFirst, .last: isLast]
        ) {
            graphData.texts.append(graphText)
        }
        
        indexCounter += 1
    }
    return graphData
}
