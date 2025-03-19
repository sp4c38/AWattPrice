//
//  Setting.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.03.25.
//
//

import Foundation
import SwiftData


@Model public class Setting {
    var baseFee: Double? = 0.0
    var cheapestTimeLastConsumption: Double? = 0
    var cheapestTimeLastPower: Double? = 0
    var pricesWithVAT: Bool? = true
    var regionIdentifier: Int16? = 0
    var splashScreensFinished: Bool?
    public init() {

    }
    
}
