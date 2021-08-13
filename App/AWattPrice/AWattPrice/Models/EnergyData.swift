//
//  EnergyData.swift
//  AWattPrice
//
//  Created by Léon Becker on 13.08.21.
//

import Foundation

struct EnergyPricePoint: Decodable {
    let startTime: Date
    let endTime: Date
    let marketprice: Double
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_timestamp"
        case endTime = "end_timestamp"
        case marketprice
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try values.decode(Date.self, forKey: .startTime)
        endTime = try values.decode(Date.self, forKey: .endTime)
        marketprice = try values.decode(Double.self, forKey: .marketprice).euroMWhToCentkWh
    }
}

struct EnergyData: Decodable {
    let prices: [EnergyPricePoint]

    static func jsonDecoder() -> JSONDecoder {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .secondsSince1970
        return jsonDecoder
    }
}

