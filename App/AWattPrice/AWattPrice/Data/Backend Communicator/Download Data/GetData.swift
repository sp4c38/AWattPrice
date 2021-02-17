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
     Store parsed energy data to a app group represented by the parsed AppGroupManager.
     
     Function won't make sure that new energy data != currently stored energy data.
     */
    internal func storeEnergyData(_ energyData: EnergyData, forRegion: Region, _ appGroupManager: AppGroupManager) {
        appGroupManager.writeEnergyDataToGroup(eneryData: energyData, forRegion: region)
        
        let storedData = appGroupManager.readEnergyData()
        if storedData != newData {
            _ = appGroupManager.writeEnergyDataToGroup(energyData: newData)
            WidgetCenter.shared.reloadTimelines(ofKind: "me.space8.AWattPrice.PriceWidget")
        }
    }
    
    /// Returns bool indicating if the app/widget needs to check for new data polling the backend.
    private func energyDataNeedsBackendUpdate(_ energyData: EnergyData) -> Bool {
        guard let lastItemStart = energyData.prices.last?.startTimestamp else { return true }
        
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = rotation.timeZone

        let startToday = calendar.startOfDay(for: now)
        let dayDifference = calendar.dateComponents([.day], from: startToday, to: lastItemStart).day!
        
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
            (data, dataFromCache, error) = download(region)
            if data != nil {
                parsedRemotely = parseResponseData(data!, region, includingAllPricePointsAfter: includeDate)
            }
        }

        if parsedLocally != nil, parsedRemotely != nil, parsedLocally != parsedRemotely {
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
     
     First, checks if a app storage entry for the energy data entry exists.
     If not it polls energy data from the backend.
     If an entry exists, it checks if the stored data is due for update. If not it just parses the data. If it is due it downloads from the backend and parses.
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
        let backgroundQueue = DispatchQueue.global(qos: .userInteractive)
        runInQueueIf(isTrue: runAsync, in: backgroundQueue) {
            let parsedData = self.getParsedData(
                region, appGroupManager
            )

            self.setClassDataAndErrors(
                parsedData,
                timeBefore,
                networkManager,
                runAsync
            )
            
            if parsedData.newDataPricePoints {
                // newDataPricePoints is only set to true if data != nil
                self.storeEnergyData(parsedData.data!, forRegion: region, appGroupManager)
            }
        }
    }
}
