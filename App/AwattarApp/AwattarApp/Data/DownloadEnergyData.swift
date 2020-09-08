//
//  DownloadEnergyData.swift
//  AwattarApp
//
//  Created by Léon Becker on 07.09.20.
//

import Foundation

struct AwattarDataPoint: Codable {
    var startTimestamp: Int
    var endTimestamp: Int
    var marketprice: Float
    var unit: String
    
    enum CodingKeys: String, CodingKey {
        case startTimestamp = "start_timestamp"
        case endTimestamp = "end_timestamp"
        case marketprice = "marketprice"
        case unit = "unit"
    }
}

struct AwattarData: Codable {
    var prices: [AwattarDataPoint]
    var maxPrice: Float?
    
    enum CodingKeys: String, CodingKey {
        case prices = "prices"
        case maxPrice = "max_price"
    }
}

struct SourcesData: Codable {
    var awattar: AwattarData
}

class EnergyData: ObservableObject {
    @Published var energyData: SourcesData? = nil

    init() {
        var request = URLRequest(
                        url: URL(string: "https://www.space8.me:9173/awattar_app/data/")!,
                        cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy)
        
        request.httpMethod = "GET"
        
        let _ = URLSession.shared.dataTask(with: request) { data, response, error in
            let jsonDecoder = JSONDecoder()
            var decodedData = SourcesData(awattar: AwattarData(prices: [], maxPrice: nil))
            
            if let data = data {
                do {
                    decodedData = try jsonDecoder.decode(SourcesData.self, from: data)
                    DispatchQueue.main.async {
                        self.energyData = decodedData
                    }
                } catch {
                    fatalError("Could not decode returned JSON data from server.")
                }
            }
        }.resume()
    }
}
