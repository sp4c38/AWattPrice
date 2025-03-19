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
    
    var taxMultiplier: Double? {
        switch self {
        case .DE:
            return 1.19
        case .AT:
            return 1.20
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apiName)
    }
    
    // No need to implement init(from:) since it's an Int16-based enum
    // and SwiftData can handle that automatically
}
