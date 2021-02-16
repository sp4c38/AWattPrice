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

    private func getParsedData(
        _ region: Region,
        _ appGroupManager: AppGroupManager
    ) -> (EnergyData?, Bool, Error?) {
        var (data, dataFromCache, error): (Data?, Bool, Error?) = (nil, true, nil)
        (data, error) = appGroupManager.getEnergyDataStored(for: region)
        
        var pollFromServer = true
        // If data is nil, pollFromServer is already set to true.
        
        var parsed: EnergyData? = nil
        if data != nil {
            parsed = self.parseResponseData(data!, region)
            if parsed != nil {
                pollFromServer = energyDataNeedsBackendUpdate(parsed!)
            }
        }
        if pollFromServer {
            (data, dataFromCache, error) = self.download(region)
            if data != nil {
                parsed = self.parseResponseData(data!, region)
            }
        }
        
        return (parsed, dataFromCache, error)
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
            let (parsedData, dataFromCache, error) = self.getParsedData(
                region, appGroupManager
            )
            
            self.setClassDataAndErrors(
                parsedData,
                error,
                timeBefore,
                dataFromCache,
                networkManager,
                runAsync
            )
//            self.checkAndStoreToAppGroup(appGroupManager, energyData)
        }
    }
}
