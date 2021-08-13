//
//  APIClient.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Combine
import Foundation

class APIClient<ResponseType: Decodable> {
    func request<ResponseDataType, DecoderType>(to apiRequest: APIRequest<ResponseDataType, DecoderType>) -> AnyPublisher<ResponseDataType, Error> {
        self.request(request: apiRequest.request)
            .map(\.data)
            .decode(type: ResponseDataType.self, decoder: apiRequest.decoder)
            .eraseToAnyPublisher()
    }
    
    func request(request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .eraseToAnyPublisher()
    }
}
