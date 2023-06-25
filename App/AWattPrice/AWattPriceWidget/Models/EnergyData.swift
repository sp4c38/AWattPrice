//
//  EnergyData.swift
//  AWattPrice
//
//  Created by Léon Becker on 25.06.23.
//

import Foundation

struct EnergyPricePoint: Decodable {
    var startTime: Date
    var endTime: Date
    var marketprice: Double
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_timestamp"
        case endTime = "end_timestamp"
        case marketprice
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try values.decode(Date.self, forKey: .startTime)
        endTime = try values.decode(Date.self, forKey: .endTime)
        
        var decodedMarketprice = try values.decode(Double.self, forKey: .marketprice)
        decodedMarketprice = decodedMarketprice.euroMWhToCentkWh
        if decodedMarketprice.isZero, decodedMarketprice.sign == .minus {
            decodedMarketprice = abs(decodedMarketprice)
        }
        marketprice = decodedMarketprice
    }
    
    static let marketpricesAreInIncreasingOrder: (EnergyPricePoint, EnergyPricePoint) -> Bool = { lhsPricePoint, rhsPricePoint in
        rhsPricePoint.marketprice > lhsPricePoint.marketprice ? true : false
    }
}


struct EnergyData: Decodable {
    let prices: [EnergyPricePoint]
    
    var currentPrices: [EnergyPricePoint] = []
    
    enum CodingKeys: CodingKey {
        case prices
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        prices = try values.decode([EnergyPricePoint].self, forKey: .prices)
        processCalculatedValues()
    }
    
    init(prices: [EnergyPricePoint]) {
        self.prices = prices
        processCalculatedValues()
    }
    
    mutating func processCalculatedValues() {
        let now = Date()
        let hourStart = Calendar.current.startOfHour(for: now)
        currentPrices = prices
            .compactMap { $0.startTime >= hourStart ? $0 : nil }
            .sorted { lhsPricePoint, rhsPricePoint in
                rhsPricePoint.startTime > lhsPricePoint.startTime ? true : false
            }
    }
    
    static func jsonDecoder() -> JSONDecoder {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .secondsSince1970
        return jsonDecoder
    }
    
    static func downloadEnergyData() async -> EnergyData? {
        let apiURL: URL = {
            #if DEBUG
            return URL(string: "https://test-awp.space8.me/api/v2/")!
            #else
            return URL(string: "https://awattprice.space8.me/api/v2/")!
            #endif
        }()
        
        let requestURL = apiURL
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent(Region.DE.apiName)
        
        let urlRequest = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        
        var data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            print("Couldn't download energy data: \(error).")
            return nil
        }
        
        do {
            return try EnergyData.jsonDecoder().decode(EnergyData.self, from: data)
        } catch {
            print("Couldn't parse downloaded energy data as expected JSON: \(error).")
            return nil
        }
    }

}
