//
//  BackendCommunicator.swift
//  AWattPrice
//
//  Created by Léon Becker on 22.01.21.
//

import Foundation

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
}
