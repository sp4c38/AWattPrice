//
//  DataParser.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.02.21.
//

import SwiftUI

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

extension BackendCommunicator {
    private func handleNonSuccessfulDownload(_ runAsync: Bool) {
        logger.error("Could not decode returned JSON data from server.")
        runInQueueIf(isTrue: runAsync, in: DispatchQueue.main, runAsync: runAsync) {
            withAnimation {
                self.dataRetrievalError = true
            }
        }
    }
    
    private func parseMarketprice(_ marketprice: Double) -> Double {
        var newMarketprice: Double = (marketprice * 100).rounded() / 100 // Round to two decimal places

        if marketprice.sign == .minus && marketprice == 0 {
            newMarketprice = 0
        }
        return newMarketprice
    }
    
    private func getNewMinMaxPrices(
        _ marketprice: Double, _ minPrice: Double, _ maxPrice: Double
    ) -> (Double, Double) {
        var newMinPrice = minPrice
        var newMaxPrice = maxPrice
        
        if marketprice > maxPrice {
            newMaxPrice = marketprice
        }

        if marketprice < 0 && marketprice < minPrice {
            newMinPrice = marketprice
        }
        return (newMinPrice, newMaxPrice)
    }
    
    internal func parseResponseData(_ data: Data, runAsync: Bool = true) {        
        let decodedData = decodeJSONResponse(data, asType: EnergyData.self)
        guard var data = decodedData else {
            handleNonSuccessfulDownload(runAsync)
            return
        }

        let startCurrentHour = Calendar.current.startOfHour(for: Date())
        
        var newPrices = [EnergyPricePoint]()
        var newMinPrice: Double = 0
        var newMaxPrice: Double = 0
        for pointIndex in 0..<data.prices.count {
            if data.prices[pointIndex].startTimestamp < startCurrentHour {
                continue
            }
            
            let newMarketprice = parseMarketprice(data.prices[pointIndex].marketprice)
            data.prices[pointIndex].marketprice = newMarketprice
            
            newPrices.append(data.prices[pointIndex])
            
            (newMinPrice, newMaxPrice) = getNewMinMaxPrices(newMarketprice, newMinPrice, newMaxPrice)
        }

        data.prices = newPrices
        data.minPrice = newMinPrice
        data.maxPrice = newMaxPrice
        
        runInQueueIf(isTrue: runAsync, in: DispatchQueue.main, runAsync: runAsync) {
            if data.prices.isEmpty {
                logger.notice("No prices can be displayed: either there are none or they are outdated.")
                withAnimation {
                    self.currentlyNoData = true
                }
            } else {
                self.energyData = data
            }

            self.dataRetrievalError = false
        }
    }
}
