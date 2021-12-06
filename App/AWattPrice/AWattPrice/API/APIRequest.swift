//
//  APIRequest.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Combine
import Foundation

protocol APIRequest {
    var urlRequest: URLRequest { get }
    var expectedResponseCode: Int? { get }
}

/// APIRequest which expects a decodable response.
struct ResponseAPIRequest<ResponseType: Decodable, DecoderType: TopLevelDecoder>: APIRequest where DecoderType.Input == Data {
    var urlRequest: URLRequest
    var expectedResponseCode: Int? = nil
    let decoder: DecoderType
}

/// APIRequest which doesn't expect any response.
struct PlainAPIRequest: APIRequest {
    let urlRequest: URLRequest
    var expectedResponseCode: Int? = nil
}

enum APIRequestFactory {
    static let apiURL = AppContext.shared.config.apiURL

    static func energyDataRequest(region: Region) -> ResponseAPIRequest<EnergyData, JSONDecoder> {
        let requestURL = apiURL
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent(region.apiName)
        let urlRequest = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        let decoder = EnergyData.jsonDecoder()
        return ResponseAPIRequest(urlRequest: urlRequest, expectedResponseCode: 200, decoder: decoder)
    }
    
    static func notificationRequest(_ notificationConfiguration: NotificationConfiguration) -> PlainAPIRequest? {
        guard notificationConfiguration.token != nil else {
            print("Token of the notification configuration is still nil.")
            return nil
        }
        
        let encoder = JSONEncoder()
        let encodedTasks: Data
        do {
            encodedTasks = try encoder.encode(notificationConfiguration)
        } catch {
            print("Couldn't encode notification configuration: \(error).")
            return nil
        }
        
        let requestURL = apiURL
            .appendingPathComponent("notifications", isDirectory: true)
            .appendingPathComponent("save_configuration", isDirectory: true)
        var urlRequest = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = encodedTasks
        
        return PlainAPIRequest(urlRequest: urlRequest, expectedResponseCode: 200)
    }
}
