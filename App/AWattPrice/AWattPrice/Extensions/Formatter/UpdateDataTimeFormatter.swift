//
//  RelativeDateFormatter.swift
//  AWattPrice
//
//  Created by Léon Becker on 29.11.20.
//

import Foundation

/// Simillar to the built in RelativeDateTimeFormatter but fitted to the needs of the AWattPrice App.
class UpdatedDataTimeFormatter {
    func localizedTimeString(for startDate: Date, relativeTo endDate: Date) -> String {
        let timeIntervalBetween = startDate.timeIntervalSince(endDate)
        
        if timeIntervalBetween < 60 {
            return "updateDataTimeFormatter.lessThanOneMinuteAgo".localized()
        } else {
            // More than one minute ago
            let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = 0
            let minutesBetweenString = numberFormatter.string(from: NSNumber(value: (timeIntervalBetween / 60).rounded(.down)))
            guard let _ = minutesBetweenString else { return "" }
            
            var localizableString = ""
            if timeIntervalBetween < 120 {
                localizableString = "updateDataTimeFormatter.moreThanMMAgoSingular"
            } else {
                localizableString = "updateDataTimeFormatter.moreThanMMAgoPlural"
            }
            
            return String(format: localizableString.localized(), minutesBetweenString!)
        }
    }
}
