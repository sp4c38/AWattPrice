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

/// A single energy price data point. It has a start and end time. Throughout this time range a certain marketprice/energy price applies. This price is also held in this energy price data point.
struct EnergyPricePoint: Hashable, Codable, Comparable {
    /// Will compare by start timestamp.
    static func < (lhs: EnergyPricePoint, rhs: EnergyPricePoint) -> Bool {
        lhs.startTimestamp < rhs.startTimestamp
    }

    var startTimestamp: Date
    var endTimestamp: Date
    var marketprice: Double

    enum CodingKeys: String, CodingKey {
        case startTimestamp = "start_timestamp"
        case endTimestamp = "end_timestamp"
        case marketprice
    }
}

/// A object containing all EnergyPricePoint's. It also holds two values for the smallest and the largest energy price of all containing energy data points.
struct EnergyData: Equatable {
    var prices: [EnergyPricePoint]
    var minPrice: Double = 0
    var maxPrice: Double = 0

    enum CodingKeys: String, CodingKey {
        case prices
        case minPrice
        case maxPrice
    }
}

extension EnergyData: Encodable {
    func encode(to encoder: Encoder, withMinMaxPrice _: Bool) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prices, forKey: .prices)
        try container.encodeIfPresent(minPrice, forKey: .minPrice)
        try container.encodeIfPresent(maxPrice, forKey: .minPrice)
    }
}

extension EnergyData: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        prices = try values.decode([EnergyPricePoint].self, forKey: .prices)

        if let minPriceDecoded = try values.decodeIfPresent(Double.self, forKey: .minPrice) {
            minPrice = minPriceDecoded
        } else { minPrice = 0 }
        if let maxPriceDecoded = try values.decodeIfPresent(Double.self, forKey: .maxPrice) {
            maxPrice = maxPriceDecoded
        } else { maxPrice = 0 }
    }
}

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
    // Download methods

    /// Runs the tasks asynchronous if runAsync is true. If not the tasks will be ran synchronous. All tasks are run in in the specified run queue (for example: main queue, the global queue with qos background).
    internal func runQueueSyncOrAsync(
        _ runQueue: DispatchQueue,
        _ runAsync: Bool,
        deadlineIfAsync: DispatchTime? = nil,
        tasks: @escaping () -> ()
    ) {
        if runAsync {
            if deadlineIfAsync != nil {
                runQueue.asyncAfter(deadline: deadlineIfAsync!) {
                    tasks()
                }
            } else {
                runQueue.async {
                    tasks()
                }
            }
        } else {
            runQueue.sync {
                tasks()
            }
        }
    }
    
    /// Will run the tasks (synchronous or asynchronous) in the specified run queue if the condition is true. Therefor the function runQueueSyncOrAsync is used in the background. If the condition is false the tasks will be ran synchronous in the current queue.
    internal func runInQueueIf(
        isTrue condition: Bool,
        in runQueue: DispatchQueue,
        runAsync: Bool,
        tasks: @escaping () -> ()
    ) {
        if condition {
            runQueueSyncOrAsync(runQueue, runAsync) {
                tasks()
            }
        } else {
            tasks()
        }
    }
    
    /// Downloads the newest aWATTar data
    func download(
        _ appGroupManager: AppGroupManager,
        _ regionIdentifier: Int16,
        _ networkManager: NetworkManager,
        runAsync: Bool = true
    ) {
        currentlyUpdatingData = true
        dataRetrievalError = false

        var downloadURL = ""

        if regionIdentifier == 1 {
            downloadURL = GlobalAppSettings.rootURLString + "/data/AT"
        } else {
            downloadURL = GlobalAppSettings.rootURLString + "/data/DE"
        }

        var energyRequest = URLRequest(
            url: URL(string: downloadURL)!,
            cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy
        )

        energyRequest.httpMethod = "GET"

        var dataComesFromCache = false
        if URLCache.shared.cachedResponse(for: energyRequest) != nil {
            dataComesFromCache = true
        }
        
        let semaphore = DispatchSemaphore(value: 1)
        let beforeTime = Date()
        URLSession.shared.dataTask(with: energyRequest) { data, _, error in
            if let data = data {
                self.parseResponseData(data, runAsync: runAsync)
            } else {
                print("A data retrieval error occurred.")
                if error != nil {
                    self.runQueueSyncOrAsync(DispatchQueue.main, runAsync) {
                        withAnimation {
                            self.dataRetrievalError = true
                        }
                    }
                }
            }

            self.runQueueSyncOrAsync(DispatchQueue.main, runAsync) {
                if dataComesFromCache == true, networkManager.monitorer.currentPath.status == .unsatisfied {
                    self.dataRetrievalError = true
                }

                if !self.dataRetrievalError {
                    self.dateDataLastUpdated = Date()
                    self.runQueueSyncOrAsync(DispatchQueue.global(qos: .background), runAsync) {
                        var newEnergyData: EnergyData?
                        self.runInQueueIf(isTrue: runAsync, in: DispatchQueue.main, runAsync: false) {
                            newEnergyData = self.energyData
                        }
                        self.checkAndStoreDataToAppGroup(appGroupManager, newEnergyData)
                    }
                }

                if Date().timeIntervalSince(beforeTime) < 0.6 {
                    self.runQueueSyncOrAsync(
                        DispatchQueue.main,
                        runAsync,
                        deadlineIfAsync: .now() + (0.6 - Date().timeIntervalSince(beforeTime))
                    ) {
                        // If the data could be retrieved very fast (< 0.6s) than changes to text, ... could look very sudden.
                        // Thats why add a small delay to result in a 0.6s delay.
                        self.currentlyUpdatingData = false
                    }
                } else {
                    self.currentlyUpdatingData = false
                }
            }
            semaphore.signal()
        }.resume()
        
        if runAsync {
            semaphore.wait()
        }
    }
}

extension BackendCommunicator {
    // Parsing methods

    func parseResponseData(_ data: Data, runAsync: Bool = true) {
        var decodedData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
        do {
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .secondsSince1970

            decodedData = try jsonDecoder.decode(EnergyData.self, from: data)
            let currentHour = Calendar.current.date(
                bySettingHour: Calendar.current.component(.hour, from: Date()),
                minute: 0,
                second: 0, of: Date()
            )!

            var usedPricesDecodedData = [EnergyPricePoint]()
            var minPrice: Double?
            var maxPrice: Double?

            for hourPoint in decodedData.prices {
                if hourPoint.startTimestamp >= currentHour {
                    var marketprice: Double = (hourPoint.marketprice * 100).rounded() / 100 // Round to two decimal places

                    if marketprice.sign == .minus && marketprice == 0 {
                        marketprice = 0
                    }

                    usedPricesDecodedData.append(
                        EnergyPricePoint(startTimestamp: hourPoint.startTimestamp,
                                         endTimestamp: hourPoint.endTimestamp,
                                         marketprice: marketprice)
                    )

                    if maxPrice == nil || marketprice > maxPrice! {
                        maxPrice = marketprice
                    }

                    if minPrice == nil {
                        if marketprice < 0 {
                            minPrice = marketprice
                        }
                    } else if marketprice < minPrice! {
                        minPrice = marketprice
                    }
                }
            }

            let currentEnergyData = EnergyData(prices: usedPricesDecodedData, minPrice: minPrice ?? 0, maxPrice: maxPrice ?? 0)

            self.runQueueSyncOrAsync(DispatchQueue.main, runAsync) {
                if currentEnergyData.prices.isEmpty {
                    print("No prices can be shown, because either there are none or they are outdated.")
                    withAnimation {
                        self.currentlyNoData = true
                    }
                } else {
                    self.energyData = currentEnergyData
                }

                self.dataRetrievalError = false
            }
        } catch {
            print("Could not decode returned JSON data from server.")
            self.runQueueSyncOrAsync(DispatchQueue.main, runAsync) {
                withAnimation {
                    self.dataRetrievalError = true
                }
            }
        }
    }
}

extension BackendCommunicator {
    func checkAndStoreDataToAppGroup(_ appGroupManager: AppGroupManager, _ newDataToCheck: EnergyData?) {
        guard let newData = newDataToCheck else { return }
        let setGroupSuccessful = appGroupManager.setGroup(AppGroups.awattpriceGroup)
        guard setGroupSuccessful else { return }
        let storedData = appGroupManager.readEnergyDataFromGroup()
        if storedData != newData {
            WidgetCenter.shared.reloadTimelines(ofKind: "me.space8.AWattPrice.PriceWidget")
            _ = appGroupManager.writeEnergyDataToGroup(energyData: newData)
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
