//
//  DataValidity.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.02.21.
//

import Foundation

import Network
import WidgetKit

extension BackendCommunicator {
    /**
     Performs multiple tasks which are needed when new price points could be retrieved.
     */
    internal func newPricePointsAvailable(_ parsed: ExtendedParsedData, _ appGroupManager: AppGroupManager) {
        var writeToAppGroupSuccessful = false
        
        do {
            try appGroupManager.writeEnergyDataToGroup(parsed.data!)
            writeToAppGroupSuccessful = true
        } catch {
            logger.error("New price points available, but error storing to app group: \(error.localizedDescription).")
        }
        if writeToAppGroupSuccessful {
            WidgetCenter.shared.reloadTimelines(ofKind: "me.space8.AWattPrice.PriceWidget")
        }
    }
    
    /// Returns bool indicating if the app/widget needs to check for new data polling the backend.
    private func energyDataNeedsBackendUpdate(_ energyData: EnergyData) -> Bool {
        guard let lastItemEnd = energyData.prices.last?.endTimestamp else { return true }
        
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = rotation.timeZone

        let startToday = calendar.startOfDay(for: now)
        let dayDifference = calendar.dateComponents([.day], from: startToday, to: lastItemEnd).day!
        
        if dayDifference == 1 { // Price data for the following day either doesn't exist at all or is uncomplete.
            if now >= self.rotation.rotationDate {
                return true
            } else {
                return false
            }
        } else if dayDifference > 1 { // Price data for following day is already completely available
            return false
        } else if dayDifference < 1 { // Should never happen. Occurs when price data for the current day either doesn't exist or is uncomplete.
            return true
        }
        return true
    }

    struct ExtendedParsedData {
        var data: EnergyData?
        var newDataPricePoints: Bool // Set to true if new data price points were added
        var dataFromCache: Bool
        var error: Error? // Any error occurred while retrieving the data.
    }
    
    private func getParsedData(
        _ region: Region,
        _ appGroupManager: AppGroupManager
    ) -> ExtendedParsedData {
        var dataFromCache = true
        var newDataPricePoints = false
        var (data, error) = appGroupManager.getEnergyDataStored(for: region)
        
        let now = Date()
        // Include all energy price points >= this time
        let includeDate = Calendar.current.startOfHour(for: now)
        
        var pollFromServer = true
        // If data is nil, pollFromServer is already set to true.
        
        var parsedLocally: EnergyData? = nil // Stored parsed energy data
        if data != nil {
            parsedLocally = parseResponseData(data!, region, includingAllPricePointsAfter: includeDate)
            if parsedLocally != nil {
                pollFromServer = energyDataNeedsBackendUpdate(parsedLocally!)
            }
        }
        
        var parsedRemotely: EnergyData? = nil // Remotely parsed energy data
        if pollFromServer {
            logger.debug("Need to download energy data from backend.")
            (data, dataFromCache, error) = download(region)
            if data != nil {
                parsedRemotely = parseResponseData(data!, region, includingAllPricePointsAfter: includeDate)
            }
        } else {
            logger.debug("Local energy data up to date.")
        }

        if (parsedLocally == nil && parsedRemotely != nil) ||
           (parsedLocally != nil && parsedRemotely != nil && parsedLocally != parsedRemotely)
        {
            newDataPricePoints = true
        }
        
        // Parsed data to actually use
        let parsed = parsedRemotely != nil ? parsedRemotely : parsedLocally
        
        let parsedData = ExtendedParsedData(
            data: parsed, newDataPricePoints: newDataPricePoints, dataFromCache: dataFromCache, error: error
        )
        
        return parsedData
    }
    
    /**
     Gets current energy data.
     
     Always run on DispatchQueue.main - use runAsync to specify if function should fall through or if it should wait until results were retrieved.
     If app storage energy data is still up to date, return, otherwise return energy data polled from backend.
    */
    func getEnergyData(
        _ regionIdentifier: Int16,
        _ networkManager: NetworkManager,
        runAsync: Bool = true
    ) {
        guard let region = Region(rawValue: Int(regionIdentifier)) else {
            logger.error("Invalid region parsed when getting energy data.")
            return
        }
        guard let appGroupManager = AppGroupManager(withID: AppGroups.awattpriceGroup) else { return }
        
        let timeBefore = Date()
        let runQueue = DispatchQueue.global(qos: .userInteractive)
        runAsyncInQueueIf(isTrue: runAsync, in: runQueue) {
            let parsedData = self.getParsedData(
                region, appGroupManager
            )

            self.setClassDataAndErrors(
                parsedData,
                timeBefore,
                networkManager,
                runAsync
            )
            
            if parsedData.newDataPricePoints, parsedData.data != nil {
                logger.debug("Energy data contains new prices.")
                self.newPricePointsAvailable(parsedData, appGroupManager)
            }
        }
    }
}
