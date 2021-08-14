//
//  DataValidity.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.02.21.
//

import Foundation

import Network
import WidgetKit

//extension BackendCommunicator {
//    /**
//     Performs multiple tasks which are needed when new price points could be retrieved.
//     */
//    internal func newPricePointsAvailable(_ parsed: ExtendedParsedData, _ appGroupManager: AppGroupManager) {
//        var writeToAppGroupSuccessful = false
//
//        do {
//            try appGroupManager.writeEnergyDataToGroup(parsed.data!)
//            writeToAppGroupSuccessful = true
//        } catch {
//            logger.error("New price points available, but error storing to app group: \(error.localizedDescription).")
//        }
//        if writeToAppGroupSuccessful {
//            WidgetCenter.shared.reloadTimelines(ofKind: "me.space8.AWattPrice.PriceWidget")
//        }
//    }
//
//    /// Returns bool indicating if the app/widget needs to check for new data polling the backend.
//    private func energyDataNeedsBackendUpdate(_ energyData: EnergyData) -> Bool {
//        guard let lastItemEnd = energyData.prices.last?.endTimestamp else { return true }
//
//        let now = Date()
//        var calendar = Calendar(identifier: .gregorian)
//        calendar.timeZone = rotation.timeZone
//
//        let startToday = calendar.startOfDay(for: now)
//        let dayDifference = calendar.dateComponents([.day], from: startToday, to: lastItemEnd).day!
//
//        if dayDifference == 1 { // Price data for the following day either doesn't exist at all or is uncomplete.
//            if now >= self.rotation.rotationDate {
//                logger.debug("Energy data due to update.")
//                return true
//            } else {
//                let hoursRemaining = rotation.rotationDate.timeIntervalSince(now) / 3600
//                let remainingRounded = (hoursRemaining * 1000).rounded() / 1000
//                logger.debug("Energy data due update today but not yet past rotation time: \(remainingRounded)h remaining.")
//                return false
//            }
//        } else if dayDifference > 1 { // Price data for following day is already completely available
//            logger.debug("Energy data up to date.")
//            return false
//        } else if dayDifference < 1 { // Should never happen. Occurs when price data for the current day either doesn't exist or is uncomplete.
//            logger.debug("Energy data for current day uncomplete and due for update.")
//            return true
//        }
//        return true
//    }
//
//    private func getParsedData(
//        _ region: Region,
//        _ appGroupManager: AppGroupManager
//    ) -> ExtendedParsedData {
//        var dataFromCache = true
//        var newDataPricePoints = false
//        var (data, error) = appGroupManager.getEnergyDataStored(for: region)
//
//        let now = Date()
//        // Include all energy price points >= this time
//        let includeDate = Calendar.current.startOfHour(for: now)
//
//        var pollFromServer = true
//        // If data is nil, pollFromServer is already set to true.
//
//        var parsedLocally: EnergyData? = nil // Stored parsed energy data
//        if data != nil {
//            parsedLocally = parseResponseData(data!, region, includingAllPricePointsAfter: includeDate)
//            if parsedLocally != nil {
//                pollFromServer = energyDataNeedsBackendUpdate(parsedLocally!)
//            }
//    }
//}
