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
    internal func checkAndStoreToAppGroup(_ appGroupManager: AppGroupManager, _ newDataToCheck: EnergyData?) {
        guard let newData = newDataToCheck else { return }
        let setGroupSuccessful = appGroupManager.setGroup(AppGroups.awattpriceGroup)
        guard setGroupSuccessful else { return }
        
        let storedData = appGroupManager.readEnergyData()
        if storedData != newData {
            _ = appGroupManager.writeEnergyDataToGroup(energyData: newData)
            WidgetCenter.shared.reloadTimelines(ofKind: "me.space8.AWattPrice.PriceWidget")
        }
    }
    
    internal func setClassDataAndErrors(
        _ data: EnergyData?,
        _ error: Error?,
        _ timeBefore: Date,
        _ dataFromCache: Bool,
        _ networkManager: NetworkManager,
        _ runAsync: Bool
    ) {
        DispatchQueue.main.sync {
            if data != nil {
                if data!.prices.isEmpty {
                    logger.notice("No prices can be displayed: either there are none or they are outdated.")
                    withAnimation {
                        self.currentlyNoData = true
                    }
                } else {
                    self.energyData = data!
                }
            } else {
                logger.notice("Data retrieval error after trying to reach server (e.g.: server could be offline).")
                withAnimation {
                    self.dataRetrievalError = true
                }
            }
            
            if dataFromCache == true, networkManager.monitorer.currentPath.status == .unsatisfied {
                // Show cached data and a notice that no fresh data could be fetched.
                self.dataRetrievalError = true
            }

            if Date().timeIntervalSince(timeBefore) < 0.6 {
                runInQueueIf(
                    isTrue: runAsync,
                    in: DispatchQueue.main,
                    runAsync: runAsync,
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
    
    /// Downloads the newest aWATTar data. This function must be run in a queue other than DispatchQueue.main!
    internal func download(_ region: Region) -> (Data?, Bool, Error?) {
        logger.debug("Downloading aWATTar data.")
        
        DispatchQueue.main.sync {
            currentlyUpdatingData = true
            dataRetrievalError = false
        }
        
        var downloadURL = ""
        if region == .DE {
            downloadURL = GlobalAppSettings.rootURLString + "/data/DE"
        } else if region == .AT {
            downloadURL = GlobalAppSettings.rootURLString + "/data/AT"
        }
        
        var energyRequest = URLRequest(
            url: URL(string: downloadURL)!,
            cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy
        )
        energyRequest.httpMethod = "GET"
        
        var dataDownloaded: Data? = nil
        var dataFromCache = false
        var downloadErrors: Error? = nil
        if let cachedResponse = URLCache.shared.cachedResponse(for: energyRequest) {
            dataDownloaded = cachedResponse.data
            dataFromCache = true
        } else {
            let semaphore = DispatchSemaphore(value: 0)
            
            URLSession.shared.dataTask(with: energyRequest) { data, _, error in
                dataDownloaded = data
                downloadErrors = error
                
                semaphore.signal()
            }.resume()
            
            semaphore.wait()
        }
        
        return (dataDownloaded, dataFromCache, downloadErrors)
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
