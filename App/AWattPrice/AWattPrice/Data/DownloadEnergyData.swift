//
//  DownloadEnergyData.swift
//  AwattarApp
//
//  Created by Léon Becker on 07.09.20.
//

import SwiftUI
import Foundation

/// A single energy price data point. It has a start and end time. Throughout this time range a certain marketprice/energy price applies. This price is also held in this energy price data point.
struct EnergyPricePoint: Hashable, Codable {
    var startTimestamp: Int
    var endTimestamp: Int
    var marketprice: Float
    
    enum CodingKeys: String, CodingKey {
        case startTimestamp = "start_timestamp"
        case endTimestamp = "end_timestamp"
        case marketprice = "marketprice"
    }
}

/// A object containing all EnergyPricePoint's. It also holds two values for the smallest and the largest energy price of all containing energy data points.
struct EnergyData: Codable {
    var prices: [EnergyPricePoint]
    var minPrice: Float = 0
    var maxPrice: Float = 0
    
    enum CodingKeys: String, CodingKey {
        case prices = "prices"
    }
}

/// A single aWATTar Profile with a name and an name of the image representing this profile.
struct Profile: Hashable {
    var name: String
    var imageName: String
}

/// Defines all profiles that exist.
struct ProfilesData {
    var profiles = [
        Profile(name: "HOURLY", imageName: "HourlyProfilePicture")]
}

/// Object responsible for downloading the current energy prices from the backend, decoding this data and providing it to all views which need it. It also includes data for the different profiles/tariffs of aWATTar which don't need to be downloaded.
class AwattarData: ObservableObject {
    // Needs to be an observable object because the data is downloaded asynchronously from the server
    // and views need to check whether downloading the data finished or not
    
    @Published var dataRetrievalError = false // A value representing if network connection errors occurred while trying to download the data from the backend.
    @Published var currentlyNoData = false // A value which is set to true if the price data in the downloaded data is empty.
    @Published var energyData: EnergyData? = nil
    @Published var profilesData = ProfilesData()

    func download() {
        self.dataRetrievalError = false
        self.currentlyNoData = false
        
        var energyRequest = URLRequest(
                        url: URL(string: "https://awattprice.space8.me/data/")!,
                        cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy)
        
        energyRequest.httpMethod = "GET"
        
        let _ = URLSession.shared.dataTask(with: energyRequest) { data, response, error in
            let jsonDecoder = JSONDecoder()
            var decodedData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
            
            if let data = data {
                do {
                    decodedData = try jsonDecoder.decode(EnergyData.self, from: data)
                    let currentHour = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date())!

                    var usedPricesDecodedData = [EnergyPricePoint]()
                    var minPrice: Float? = nil
                    var maxPrice: Float? = nil
                    
                    for hourPoint in decodedData.prices {
                        if Date(timeIntervalSince1970: TimeInterval(hourPoint.startTimestamp)) >= currentHour {
                            usedPricesDecodedData.append(EnergyPricePoint(startTimestamp: hourPoint.startTimestamp, endTimestamp: hourPoint.endTimestamp, marketprice: hourPoint.marketprice))
                            
                            if maxPrice == nil || hourPoint.marketprice > maxPrice! {
                                maxPrice = hourPoint.marketprice
                            }
                            
                            if minPrice == nil {
                                if hourPoint.marketprice < 0 {
                                    minPrice = hourPoint.marketprice
                                }
                            } else if hourPoint.marketprice < minPrice! {
                                minPrice = hourPoint.marketprice
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        // Set data in main thread
                        
                        self.energyData = EnergyData(prices: usedPricesDecodedData, minPrice: (minPrice != nil ? minPrice! : 0), maxPrice: (maxPrice != nil ? maxPrice! : 0))
                        
                        if self.energyData!.prices.isEmpty {
                            withAnimation {
                                self.currentlyNoData = true
                            }
                        }
                        
                    }
                } catch {
                    print("Could not decode returned JSON data from server.")
                    DispatchQueue.main.async {
                        withAnimation {
                            self.dataRetrievalError = true
                        }
                    }
                }
            } else {
                print("A internet connection error occurred.")
                if error != nil {
                    print("The internet connection appears to be offline.")
                    DispatchQueue.main.async {
                        withAnimation {
                            self.dataRetrievalError = true
                        }
                    }
                }
            }
        }.resume()
    }
}
