//
//  TotalTimeFormatter.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.12.20.
//

import Foundation

class TotalTimeFormatter {
    func string(hour: Int, minute: Int) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        let hourString = numberFormatter.string(for: hour) ?? ""
        let minuteString = numberFormatter.string(for: minute) ?? ""

        if hour == 0, minute > 0, minute < 1 {
            return String("<1min".localized())
        } else if hour > 0, minute > 0 {
            return String(format: "%@h, %@min".localized(), hourString, minuteString)
        } else if hour > 0, !(minute > 0) {
            return String(format: "%@h".localized(), hourString)
        } else if minute > 0, !(hour > 0) {
            return String(format: "%@min".localized(), minuteString)
        } else {
            return String("<1min".localized())
        }
    }
}
