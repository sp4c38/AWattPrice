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
        ZStack {
            Path { path in
                path.addRect(
                    CGRect(
                        x: graphPoint.startX, y: graphProperties.allHeight,
                        width: graphProperties.pointWidth, height: -graphPoint.height
                    )
                )
            }
        }
    }
}

//struct GraphPoint_Previews: PreviewProvider {
//    static var previews: some View {
//        GraphPoint()
//    }
//}
