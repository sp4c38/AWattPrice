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
    
    func request(to apiRequest: PlainAPIRequest) -> AnyPublisher<Never, Error> {
        self.request(request: apiRequest.urlRequest)
            .ignoreOutput()
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func request(request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .eraseToAnyPublisher()
    }
}
