//
//  DownloadEnergyData.swift
//  AwattarApp
//
//  Created by Léon Becker on 07.09.20.
//

import Foundation
import Network
import SwiftUI
import WidgetKit

///// A single aWATTar Profile with a name and an name of the image representing this profile.
// struct Profile: Hashable {
//    var name: String
//    var imageName: String
// }
//
///// Defines all profiles that exist.
// struct ProfilesData {
//    var profiles = [
//        Profile(name: "HOURLY", imageName: "HourlyProfilePicture"),
//    ]
// }

extension BackendCommunicator {
    private func getDownloadURL(for regionIdentifier: Int16) -> String {
        var downloadURL = ""
        if regionIdentifier == 1 {
            downloadURL = GlobalAppSettings.rootURLString + "/data/AT"
        } else {
            downloadURL = GlobalAppSettings.rootURLString + "/data/DE"
        }
        return downloadURL
    }
    
    private func handleDataAndError(_ data: Data?, _ error: Error?, _ runAsync: Bool) {
        if let data = data {
            self.parseResponseData(data, runAsync: runAsync)
        } else {
            logger.notice("Data retrieval error after trying to reach server (e.g.: server could be offline).")
            
            if error != nil {
                runInQueueIf(isTrue: runAsync, in: DispatchQueue.main, runAsync: runAsync) {
                    withAnimation {
                        self.dataRetrievalError = true
                    }
                }
            }
        }
    }
    
    private func checkAndStoreToAppGroup(_ appGroupManager: AppGroupManager, _ newDataToCheck: EnergyData?) {
        guard let newData = newDataToCheck else { return }
        let setGroupSuccessful = appGroupManager.setGroup(AppGroups.awattpriceGroup)
        guard setGroupSuccessful else { return }
        
        let storedData = appGroupManager.readEnergyData()
        if storedData != newData {
            _ = appGroupManager.writeEnergyDataToGroup(energyData: newData)
            WidgetCenter.shared.reloadTimelines(ofKind: "me.space8.AWattPrice.PriceWidget")
        }
    }
    
    private func setClassDataAndErrors(
        _ appGroupManager: AppGroupManager,
        _ timeBefore: Date,
        _ dataFromCache: Bool,
        _ networkManager: NetworkManager,
        _ runAsync: Bool
    ) {
        runInQueueIf(isTrue: runAsync, in: DispatchQueue.main, runAsync: runAsync) {
            if dataFromCache == true, networkManager.monitorer.currentPath.status == .unsatisfied {
                // Show cached data and a notice that no data could be fetched.
                self.dataRetrievalError = true
            }

            if !self.dataRetrievalError {
                self.dateDataLastUpdated = Date()
                runQueueSyncOrAsync(DispatchQueue.global(qos: .background), runAsync) {
                    var newEnergyData: EnergyData? = nil
                    runInQueueIf(isTrue: runAsync, in: DispatchQueue.main, runAsync: false) {
                        newEnergyData = self.energyData
                    }
                    self.checkAndStoreToAppGroup(appGroupManager, newEnergyData)
                }
            }

            if Date().timeIntervalSince(timeBefore) < 0.6 {
                runInQueueIf(
                    isTrue: runAsync,
                    in: DispatchQueue.main,
                    runAsync: true,
                    withDeadlineIfAsync: .now() + (0.6 - Date().timeIntervalSince(timeBefore))
                ) {
                    // If the data could be retrieved very fast (< 0.6s) than changes to text, ... could look very sudden -> add delay.
                    self.currentlyUpdatingData = false
                }
            } else {
                self.currentlyUpdatingData = false
            }
        }
    }
    
    /// Downloads the newest aWATTar data
    func download(
        _ appGroupManager: AppGroupManager,
        _ regionIdentifier: Int16,
        _ networkManager: NetworkManager,
        runAsync: Bool = true
    ) {
        logger.debug("Downloading aWATTar data.")
        currentlyUpdatingData = true
        dataRetrievalError = false
        
        let downloadURL = getDownloadURL(for: regionIdentifier)
        var energyRequest = URLRequest(
            url: URL(string: downloadURL)!,
            cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy
        )
        energyRequest.httpMethod = "GET"

        var dataFromCache = false
        if URLCache.shared.cachedResponse(for: energyRequest) != nil {
            dataFromCache = true
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        let timeBefore = Date()
        URLSession.shared.dataTask(with: energyRequest) { data, _, error in
            self.handleDataAndError(data, error, runAsync)
            self.setClassDataAndErrors(
                appGroupManager, timeBefore, dataFromCache, networkManager, runAsync
            )
            semaphore.signal()
        }.resume()
        
        if !runAsync {
            semaphore.wait()
        }
    }
}

extension BackendCommunicator {
    var minMaxTimeRange: ClosedRange<Date>? {
        if energyData != nil {
            if !(energyData!.prices.count > 0) {
                return nil
            }
            // Add one or subtract one to not overlap to the next or previouse day
            let min = energyData!.prices.first!.startTimestamp
            let max = energyData!.prices.last!.endTimestamp

            return min ... max
        }
        return nil
    }
}

/// Returns false if the current time is inside of the first energy data items time.
func checkEnergyDataNeedsUpdate(_ energyData: EnergyData) -> Bool {
    guard let firstItem = energyData.prices.first else { return true }
    let now = Date()
    if now >= firstItem.startTimestamp, now < firstItem.endTimestamp {
        return false
    } else {
        return true
    }
}
