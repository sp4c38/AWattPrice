//
//  GraphHelpersExtensions.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 02.02.21.
//

import SwiftUI

extension GraphProperties {
    // Padding resolving functions
    internal func makeTextPaddings(_ paddings: [GraphTextPadding: CGFloat]?) {
        if let paddings = paddings {
            if paddings.keys.contains(.bottom) {
                textPaddings[.bottom] = paddings[.bottom]!
            }
        }
    }
    
    internal func makeTextOverlapPaddings(_ paddings: [GraphTextOverlapPadding: CGFloat]?) {
        if let paddings = paddings {
            if paddings.keys.contains(.leading) {
                textOverlapPaddings[.leading] = paddings[.leading]!
            }
            if paddings.keys.contains(.trailing) {
                textOverlapPaddings[.trailing] = paddings[.trailing]!
            }
        }
    }
    
    internal func applyGraphPaddings(_ paddings: [GraphPadding: CGFloat]?) {
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
