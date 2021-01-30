//
//  Graph.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct Graph: View {
    let priceData: EnergyData

    init(_ priceData: EnergyData) {
        self.priceData = priceData
    }
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                makeGraph(geometry)
            }
        }
        .background(background)
    }
    
    func makeGraph(_ geoProxy: GeometryProxy) -> some View {
        let graphData = createGraphData(priceData, geoProxy)
        
        return GraphBody(graphData)
    }
}

extension Graph {
    var background: some View {
        Color.white
    }
}
