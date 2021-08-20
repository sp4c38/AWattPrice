//
//  APIRequest.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Combine
import Foundation

protocol APIRequest {
    var request: URLRequest { get }
}

/// APIRequest which expects a decodable response.
struct ResponseAPIRequest<ResponseType: Decodable, DecoderType: TopLevelDecoder>: APIRequest where DecoderType.Input == Data {
    var request: URLRequest
    let decoder: DecoderType
}

/// APIRequest which doesn't expect any response.
struct PlainAPIRequest: APIRequest {
    let request: URLRequest
}

enum APIRequestFactory {
    static let apiURL = AppContext.shared.config.apiURL

    static func energyDataRequest(region: Region) -> ResponseAPIRequest<EnergyData, JSONDecoder> {
        let requestURL = apiURL
            .appendingPathComponent("data")
            .appendingPathComponent(region.apiName)
        let urlRequest = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        let decoder = EnergyData.jsonDecoder()
        return ResponseAPIRequest(request: urlRequest, decoder: decoder)
    }
    
    static func notificationRequest(packedTasks: PackedNotificationTasks) -> PlainAPIRequest? {
        if packedTasks.tasks.isEmpty == true {
            return nil
        }
        
        let encoder = JSONEncoder()
        let encodedTasks: Data
        do {
            encodedTasks = try encoder.encode(packedTasks)
        } catch {
            print("Couldn't encode notification tasks: \(error).")
            return nil
        }
        
        let requestURL = apiURL
            .appendingPathComponent("notifications")
            .appendingPathComponent("run_tasks")
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = encodedTasks
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        return PlainAPIRequest(request: urlRequest)
    }
}
