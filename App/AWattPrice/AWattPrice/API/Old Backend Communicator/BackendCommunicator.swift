//
//  BackendCommunicator.swift
//  AWattPrice
//
//  Created by Léon Becker on 22.01.21.
//

import Foundation

//struct Rotation {
//    // The hour, minute, second from which on to check for new price data.
//    var hour: Int
//    var minute: Int
//    var second: Int
//    var timeZone: TimeZone
//    var rotationDate: Date // Todays (based on timezoneID) rotation time
//
//    init(hour: Int, minute: Int, second: Int, timeZone: TimeZone, rotationDate: Date) {
//        self.hour = hour
//        self.minute = minute
//        self.second = second
//        self.timeZone = timeZone
//        self.rotationDate = rotationDate
//    }
//
//    init?(
//        hour: Int, minute: Int, second: Int, ofTimeZone timeZone: TimeZone
//    ) {
//        self.hour = hour
//        self.minute = minute
//        self.second = second
//        self.timeZone = timeZone
//
//        guard let newRotationDate = getTimeBySetting(
//            [.hour: hour, .minute: minute, .second: second], inTimeZone: timeZone
//        ) else {
//            return nil
//        }
//        rotationDate = newRotationDate
//    }
//}
//
//func rotationAtStartOfToday() -> Rotation {
//    let currentTimeZone = TimeZone.current
//    let todayStart = Calendar.current.startOfDay(for: Date())
//    let newRotation = Rotation(
//        hour: 0, minute: 0, second: 0, timeZone: currentTimeZone, rotationDate: todayStart
//    )
//    return newRotation
//}

/// Object responsible for handling any communication with the AWattPrice Backend
//class BackendCommunicator: ObservableObject {
//    // Download variables
//    @Published var currentlyNoData = false // Set to true if the price data in the downloaded data is empty.
//    @Published var currentlyUpdatingData = false
//    @Published var dateDataLastUpdated: Date?
//    @Published var dataRetrievalError = false
//    @Published var energyData: EnergyData?
//
//    // APNs Token upload variables
//    @Published var notificationUploadError = false
//
//    let rotation: Rotation
//    init() {
//        // Rotation defines the time in an certain time zone from which on, to check for new data.
//        // If the rotation cannot be created use the start of the current day.
//
//        if let timeZone = TimeZone(identifier: "Europe/Berlin"),
//           let newRotation = Rotation(hour: 12, minute: 30, second: 0, ofTimeZone: timeZone) {
//            rotation = newRotation
//        } else {
//            rotation = rotationAtStartOfToday()
//        }
//    }
//}
