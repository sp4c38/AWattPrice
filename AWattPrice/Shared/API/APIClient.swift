//
//  APIRequest.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Foundation

class APIClient {
    private enum DebugConfiguration {
        static let apiBaseURLEnvironmentKey = "AWATTPRICE_API_BASE_URL"
    }

    // MARK: - Request Types
    
    /// Protocol for API requests
    protocol Request {
        var urlRequest: URLRequest { get }
    }
    
    /// Request expecting a decodable response
    struct ResponseRequest<ResponseType: Decodable>: Request {
        var urlRequest: URLRequest
        let decoder: JSONDecoder
    }
    
    /// Request that doesn't expect a response
    struct PlainRequest: Request {
        let urlRequest: URLRequest
    }
    
    // MARK: - API Configuration

    private static let productionAPIURL = URL(string: "https://awattprice.space8.me/api/v3/")!

    static var apiURL: URL {
        if let overrideURL = debugOverrideAPIURL {
            return overrideURL
        }

        return productionAPIURL
    }

    private static var debugOverrideAPIURL: URL? {
        let environment = ProcessInfo.processInfo.environment
        guard let rawValue = environment[DebugConfiguration.apiBaseURLEnvironmentKey] else {
            return nil
        }

        return normalizedAPIURL(from: rawValue)
    }

    private static func normalizedAPIURL(from rawValue: String) -> URL? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            return nil
        }

        let normalizedValue = trimmedValue.hasSuffix("/") ? trimmedValue : "\(trimmedValue)/"
        return URL(string: normalizedValue)
    }
    
    // MARK: - Request Creation
    
    /// Creates a request for energy data for the specified market area
    static func createEnergyDataRequest(marketArea: MarketArea) -> ResponseRequest<EnergyData> {
        let requestURL = APIClient.apiURL
            .appendingPathComponent("prices", isDirectory: true)
            .appendingPathComponent(marketArea.key)
        let urlRequest = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 90
        )
        let decoder = EnergyData.jsonDecoder()
        return ResponseRequest(urlRequest: urlRequest, decoder: decoder)
    }

    static func createSupportedMarketAreasRequest() -> ResponseRequest<SupportedMarketAreasResponse> {
        let requestURL = APIClient.apiURL
            .appendingPathComponent("areas", isDirectory: true)
        let urlRequest = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        let decoder = JSONDecoder()
        return ResponseRequest(urlRequest: urlRequest, decoder: decoder)
    }
    
    /// Creates a request to save notification configuration
    static func createNotificationRequest(_ notificationConfiguration: NotificationConfiguration) -> PlainRequest? {
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
        
        let requestURL = APIClient.apiURL
            .appendingPathComponent("notifications", isDirectory: true)
            .appendingPathComponent("save_configuration", isDirectory: true)
        var urlRequest = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = encodedTasks
        
        return PlainRequest(urlRequest: urlRequest)
    }
    
    // MARK: - Request Execution
    
    /// Request that returns a decoded response
    func request<ResponseType: Decodable>(to apiRequest: ResponseRequest<ResponseType>) async throws -> ResponseType {
        let (data, _) = try await self.request(request: apiRequest.urlRequest)
        return try apiRequest.decoder.decode(ResponseType.self, from: data)
    }
    
    /// Plain request without specific response type
    func request(to apiRequest: PlainRequest) async throws -> (data: Data, response: URLResponse) {
        return try await self.request(request: apiRequest.urlRequest)
    }
    
    /// Base request method that performs the network call
    func request(request: URLRequest) async throws -> (data: Data, response: URLResponse) {
        print("Performing async url request to: \(request.url?.description ?? "nil").")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("URL response from server has status code \(httpResponse.statusCode), expected 200")
            throw URLError(.badServerResponse)
        }
        
        return (data, response)
    }
}
