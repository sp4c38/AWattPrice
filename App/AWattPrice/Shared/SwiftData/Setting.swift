//
//  Setting.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.03.25.
//
//

import Foundation
import SwiftData

@Model
public class Setting {
    var baseFee: Double = 0.0
    var taxEnabled: Bool = true
    var region: Region = .DE
    var onboarded: Bool = false // Splash screens finished
    
    public init() {
        // Empty initializer - property defaults are set above
    }
}
