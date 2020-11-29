//
//  TBBarShape.swift
//  AWattPrice
//
//  Created by Léon Becker on 28.11.20.
//

import SwiftUI

struct TBBarShape: Shape {
    
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height))
        
        return path
    }
}
