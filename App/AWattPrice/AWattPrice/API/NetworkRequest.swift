//
//  NetworkRequest.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Foundation

struct ApiUrlRequestFactory {
    static func energyDataRequest(region: Region) -> URLRequest {
        let apiURL = AppContext.shared.config.apiURL
        let requestURL = apiURL.appendingPathComponent(region.apiName)
        return URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
    }
}
