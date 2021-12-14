//
//  APIClient.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Combine
import Foundation

class APIClient {
    func request<ResponseDataType, DecoderType>(to apiRequest: ResponseAPIRequest<ResponseDataType, DecoderType>) -> AnyPublisher<ResponseDataType, Error> {
        self.request(request: apiRequest.urlRequest)
            .map(\.data)
            .decode(type: ResponseDataType.self, decoder: apiRequest.decoder)
            .eraseToAnyPublisher()
    }
    
    func request(to apiRequest: PlainAPIRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        self.request(request: apiRequest.urlRequest, expectedURLCode: apiRequest.expectedResponseCode)
            .eraseToAnyPublisher()
    }
    
    func request(request: URLRequest, expectedURLCode: Int? = nil) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        print("Performing url request to: \(request.url?.description ?? "nil").")
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { (data: Data, response: URLResponse) in
                guard let expectedURLCode = expectedURLCode else { return (data, response) }
                guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                if response.statusCode == expectedURLCode {
                    return (data, response)
                } else {
                    print("URL response from server doesn't have expected url code of \(expectedURLCode): \(response.statusCode)")
                    throw URLError(.badServerResponse)
                }
            }
            .eraseToAnyPublisher()
    }
}
