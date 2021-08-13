//
//  APIRequest.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Combine
import Foundation

struct APIRequest<ResponseType: Decodable, DecoderType: TopLevelDecoder> where DecoderType.Input == Data {
    let request: URLRequest
    let decoder: DecoderType
}

enum APIRequestFactory {
    static let apiURL = AppContext.shared.config.apiURL
    
    static func energyDataRequest(region: Region) -> APIRequest<EnergyData, JSONDecoder> {
        let requestURL = apiURL.appendingPathComponent(region.apiName)
        let urlRequest = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        let decoder = EnergyData.jsonDecoder()
        return APIRequest(request: urlRequest, decoder: decoder)
    }
}
