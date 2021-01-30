//
//  GraphPointView.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI

struct GraphPointView: View {
    let graphPoint: GraphPoint
    let graphProperties: GraphProperties
    
    var body: some View {
        PointShape()
            .frame(width: graphProperties.pointWidth, height: graphPoint.height)
            .position(
                x: graphPoint.startX + (graphProperties.pointWidth / 2),
                y: graphProperties.allHeight - (graphPoint.height / 2)
            )
    }
}

//struct GraphPoint_Previews: PreviewProvider {
//    static var previews: some View {
//        GraphPoint()
//    }
//}
