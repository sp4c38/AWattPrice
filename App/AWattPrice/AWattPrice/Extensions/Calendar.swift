//
//  Calendar.swift
//  AWattPrice
//
//  Created by Léon Becker on 08.02.21.
//

import Foundation

extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let hourAmount = self.component(.hour, from: date)
        let startOfDay = self.startOfDay(for: date)
        let startOfHour = startOfDay.addingTimeInterval(TimeInterval(hourAmount * 60 * 60))
        return startOfHour
    }
}
