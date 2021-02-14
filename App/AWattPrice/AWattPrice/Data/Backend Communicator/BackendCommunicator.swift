//
//  BackendCommunicator.swift
//  AWattPrice
//
//  Created by Léon Becker on 22.01.21.
//

import Foundation

struct Rotation {
    // The hour, minute, second from which on to check for new price data.
    var hour: Int
    var minute: Int
    var second: Int
    var timeZoneID: String
    var rotationDate: Date? = nil // Todays (based on timezoneID) rotation time
    
    init(
        hour: Int, minute: Int, second: Int, ofTimeZone timeZoneID: String
    ) {
        self.hour = hour
        self.minute = minute
        self.second = second
        self.timeZoneID = timeZoneID
        rotationDate = getTimeZoneTimeBySetting(hour: hour, minute: minute, second: second, usingTimeZone: timeZoneID)
    }
}

/// Object responsible for handling any communication with the AWattPrice Backend
class BackendCommunicator: ObservableObject {
    // Download variables
    @Published var currentlyNoData = false // Set to true if the price data in the downloaded data is empty.
    @Published var currentlyUpdatingData = false
    @Published var dateDataLastUpdated: Date?
    @Published var dataRetrievalError = false
    @Published var energyData: EnergyData?

    // APNs Token upload variables
    @Published var notificationUploadError = false
    
    let rotation: Rotation
    init() {
        // Rotation defines the time in an certain time zone from which on, to check for new data.
        rotation = Rotation(hour: 12, minute: 30, second: 0, ofTimeZone: "Europe/Berlin")
    }
}
