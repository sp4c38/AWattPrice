//
//  Graph.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct GraphBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(
                colors: [
                    Color(red: 0, green: 0.98, blue: 0.6, opacity: 1.0),
                    Color(red: 0.8, green: 0.37, blue: 0.36, opacity: 1.0)
                ]
            ),
            startPoint: .bottom,
            endPoint: .top)
            .opacity(0.7)
    }
}

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
        .background(GraphBackground())
    }
    
    func makeGraph(_ geoProxy: GeometryProxy) -> some View {
        let graphData = createGraphData(priceData, geoProxy)
        
        return ZStack {
            
        }
    }
}
