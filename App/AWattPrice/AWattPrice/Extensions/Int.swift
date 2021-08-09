//
//  Int.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.08.21.
//

import Foundation

extension Int {
    var priceString: String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none

        if let result = numberFormatter.string(from: NSNumber(value: self)) {
            return result
        } else {
            return nil
        }
    }
}
