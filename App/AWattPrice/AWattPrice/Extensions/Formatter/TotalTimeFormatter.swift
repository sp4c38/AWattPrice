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

        if hour == 0, minute > 0, minute < 1 {
            return String("totalTimeFormatter.lessThanOneMinute".localized())
        } else if hour > 0, minute > 0 {
            return String(format: "totalTimeFormatter.hourCommaMinute".localized(), hourString, minuteString)
        } else if hour > 0, !(minute > 0) {
            return String(format: "totalTimeFormatter.onlyHour".localized(), hourString)
        } else if minute > 0, !(hour > 0) {
            return String(format: "totalTimeFormatter.onlyMinute".localized(), minuteString)
        } else {
            return String("totalTimeFormatter.lessThanOneMinute".localized())
        }
    }
}
