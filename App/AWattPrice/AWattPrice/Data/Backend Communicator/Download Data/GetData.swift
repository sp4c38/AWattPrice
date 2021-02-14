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

    /**
     Gets current energy data.
     
     First, checks if a app storage entry for the energy data entry exists.
     If not it polls energy data from the backend.
     If an entry exists, it checks if the stored data is due for update. If not it just parses the data. If it is due it downloads from the backend and parses.
    */
    func getEnergyData(
        _ appGroupManager: AppGroupManager,
        _ regionIdentifier: Int16,
        _ networkManager: NetworkManager,
        runAsync: Bool = true
    ) {
        var pollFromServer = true
        
        let energyDataStored = appGroupManager.readEnergyData()
        // Also if energyDataStored is nil, pollFromServer is already set to true.

        if energyDataStored != nil {
            pollFromServer = self.checkEnergyDataNeedsBackendUpdate(basedOn: energyDataStored!, rotation)
        }

        let backgroundQueue = DispatchQueue.global(qos: .userInteractive)
        if pollFromServer {
            runInQueueIf(isTrue: runAsync, in: backgroundQueue, runAsync: runAsync) {
                self.handlePollFromServer(appGroupManager, regionIdentifier, networkManager, runAsync)
            }
        }
    }
}
