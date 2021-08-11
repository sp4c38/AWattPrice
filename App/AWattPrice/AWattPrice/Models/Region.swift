//
//  Region.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Foundation

enum Region {
    case DE, AT
    
    var apiName: String {
        switch self {
        case .DE:
            return "DE"
        case .AT:
            return "AT"
        }
    }
}
