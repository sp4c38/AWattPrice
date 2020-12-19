//
//  TotalTimeFormatter.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.12.20.
//

import Foundation

class TotalTimeFormatter {
    func localizedTotalTimeString(hour: Double, minute: Double) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        let hourString = numberFormatter.string(for: hour) ?? ""
        let minuteString = numberFormatter.string(for: minute) ?? ""
        
        if hour > 0 && minute > 0 {
            return String(format: "hourCommaMinute".localized(), hourString, minuteString)
        } else if hour > 0 && !(minute > 0) {
            return String(format: "onlyHour".localized(), hourString)
        } else if minute > 0 && !(hour > 0) {
            return String(format: "onlyMinute".localized(), minuteString)
        } else {
            return String(format: "hourCommaMinute".localized(), "", "")
        }
    }
}
