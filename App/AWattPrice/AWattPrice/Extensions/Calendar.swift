//
//  Calendar.swift
//  AWattPrice
//
//  Created by Léon Becker on 08.02.21.
//

import Foundation

extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let hours = self.component(.hour, from: date)
        return self.date(bySettingHour: hours, minute: 0, second: 0, of: date)!
    }
}
