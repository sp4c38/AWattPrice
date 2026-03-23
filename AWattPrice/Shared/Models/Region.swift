//
//  Region.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Foundation

enum Region: Int16, Codable {
    case DE = 0
    case AT = 1
    
    var apiName: String {
        switch self {
        case .DE:
            return "DE"
        case .AT:
            return "AT"
        }
    }
    
    var taxMultiplier: Double {
        switch self {
        case .DE:
            return 1.19
        case .AT:
            return 1.20
        }
    }
    
    // Remove the custom encode method which was causing the issue
    // SwiftData will now use the default Int16 raw value encoding
}
