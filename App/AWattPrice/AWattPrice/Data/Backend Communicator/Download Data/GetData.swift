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
    fileprivate func checkEnergyDataNeedsBackendUpdate(basedOn energyData: EnergyData, _ rotation: Rotation) -> Bool {
        guard let lastItemStart = energyData.prices.last?.startTimestamp else { return true }
        guard let rotationDate = rotation.rotationDate else { return true }
        
        let now = Date()

        let difference = Calendar.init(identifier: .gregorian).compare(
            lastItemStart, to: now, toGranularity: .day
        ).rawValue
        if difference > 0 {
            return false
        } else {
            if now >= rotationDate {
                 return true
            } else {
                return false
            }
        }
    }
    
    struct Rotation {
        // The hour, minute, second from which on to check for new price data.
        var hour: Int
        var minute: Int
        var second: Int
        var timeZoneID: String
        var rotationDate: Date? = nil // Todays (based on timezoneID) rotation time
        
        init(
            hour: Int, minute: Int, second: Int, of timeZoneID: String
        ) {
            self.hour = hour
            self.minute = minute
            self.second = second
            self.timeZoneID = timeZoneID
        }
    }
    
    private func handlePollFromServer(
        _ appGroupManager: AppGroupManager,
        _ regionIdentifier: Int16,
        _ networkManager: NetworkManager,
        _ runAsync: Bool
    ) {
        let timeBefore = Date()
        
        let (data, dataFromCache, error) = self.download(
            appGroupManager, regionIdentifier, networkManager
        )
        
        var energyData: EnergyData? = nil
        if data != nil {
            energyData = self.parseResponseData(data!)
        }
        
        self.setClassDataAndErrors(
            energyData, error,
            timeBefore, dataFromCache, networkManager, runAsync
        )
        self.checkAndStoreToAppGroup(appGroupManager, energyData)
    }
    
    /// Get the current energy data from the app storage. If this energy data needs to be updated or doesn't exist yet the backend is polled. If no energy data could be found at all a empty energy data object will be returned.
    func getEnergyData(
        _ appGroupManager: AppGroupManager,
        _ regionIdentifier: Int16,
        _ networkManager: NetworkManager,
        runAsync: Bool = true
    ) {
        var pollFromServer = false
        
        let energyDataStored = appGroupManager.readEnergyData()
        if energyDataStored == nil {
            pollFromServer = true
        }
        
        let rotation = Rotation( // Time from which to check for new prices
            hour: 12, minute: 0, second: 0, of: "Europe/Berlin"
        )
        if pollFromServer == false || energyDataStored != nil {
            pollFromServer = self.checkEnergyDataNeedsBackendUpdate(basedOn: energyDataStored!, rotation)
        }

        let backgroundQueue = DispatchQueue.global(qos: .userInteractive)
        runInQueueIf(isTrue: runAsync, in: backgroundQueue, runAsync: runAsync) {
            if pollFromServer {
                self.handlePollFromServer(appGroupManager, regionIdentifier, networkManager, runAsync)
            }
        }
    }
}
