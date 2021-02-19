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

extension BackendCommunicator {
    internal func setValuesForDataLoading(_ runAsync: Bool) {
        runAsyncInQueueIf(isTrue: runAsync, in: DispatchQueue.main) {
            self.currentlyUpdatingData = true
            self.dataRetrievalError = false
        }
    }
    
    /**
     Set class variables to hold parsed data and reflect errors.
     */
    internal func setClassDataAndErrors(
        _ parsed: ExtendedParsedData,
        _ timeBefore: Date,
        _ networkManager: NetworkManager,
        _ runAsync: Bool
    ) {
        runAsyncInQueueIf(isTrue: runAsync, in: DispatchQueue.main) {
            if parsed.data != nil {
                if parsed.data!.prices.isEmpty {
                    logger.critical("No prices can be displayed, either there are none or they are outdated.")
                    withAnimation {
                        self.currentlyNoData = true
                    }
                } else {
                    self.energyData = parsed.data!
                }
            } else {
                logger.notice("Data retrieval error after trying to reach server (e.g.: server could be offline).")
                withAnimation {
                    self.dataRetrievalError = true
                }
            }
            
            if parsed.dataFromCache == true, networkManager.monitorer.currentPath.status == .unsatisfied {
                // Show cached data and a notice that no fresh data could be fetched.
                self.dataRetrievalError = true
            }

            if !self.dataRetrievalError {
                self.dateDataLastUpdated = timeBefore
            }
            
            if runAsync && Date().timeIntervalSince(timeBefore) < 0.6 {
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + (0.6 - Date().timeIntervalSince(timeBefore))
                ) {
                    // If the data could be retrieved very fast (< 0.6s) than changes to text, ... could look very sudden -> add delay.
                    self.currentlyUpdatingData = false
                }
            } else {
                self.currentlyUpdatingData = false
            }
        }
    }
    
    struct CachedData {
        let data: Data
        let didExpire: Bool
        let expiresIn: TimeInterval
    }
    
    internal func checkCachedData(for request: URLRequest) -> CachedData? {
        guard let cachedResponse = URLCache.shared.cachedResponse(for: request) else { return nil }
        guard let httpResponse = cachedResponse.response as? HTTPURLResponse else { return nil }
        guard let originalRetrievalDate = httpResponse.allHeaderFields["Date"] as? String else { return nil }
        guard let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String else { return nil }
        
        guard let retrievalDate = convertHTTPTimeStringToDate(timeString: originalRetrievalDate) else { return nil }
        guard let cacheMaxAge = getHTTPCacheControlMaxAgeSeconds(cacheControlString: cacheControl) else { return nil }
        let cacheExpireDate = retrievalDate + cacheMaxAge
        
        var dataDidExpire = true
        var dataExpiresIn: TimeInterval = 0
        
        let now = Date()
        if cacheExpireDate >= now {
            dataDidExpire = false
            dataExpiresIn = cacheExpireDate.timeIntervalSince(now)
        }
        
        let responseData = cachedResponse.data
        
        let cachedData = CachedData(data: responseData, didExpire: dataDidExpire, expiresIn: dataExpiresIn)
        return cachedData
    }
    
    /**
     Downloads the newest aWATTar data.
     
     Never run in DispatchQueue.main.
     */
    internal func download(_ region: Region) -> (Data?, Bool, Error?) {
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

        let cachedData = checkCachedData(for: energyRequest)
        var needToPollFromBackend = true
        if cachedData != nil {
            if cachedData!.didExpire == false {
                needToPollFromBackend = false
            }
        }
        
        if needToPollFromBackend {
            logger.debug("Downloading energy data from backend server.")
            var dataDownloaded: Data? = nil
            var downloadErrors: Error? = nil
            
            let semaphore = DispatchSemaphore(value: 0)
            
            URLSession.shared.dataTask(with: energyRequest) { data, _, error in
                dataDownloaded = data
                downloadErrors = error
                
                semaphore.signal()
            }.resume()
            
            semaphore.wait()
            
            return (dataDownloaded, false, downloadErrors)
        } else {
            logger.debug("Local CachedURLResponse energy data didn't expire yet. Expires in \(cachedData!.expiresIn)s. ")
            return (cachedData!.data, false, nil)
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
