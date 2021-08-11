//
//  ApiClient.swift
//  AWattPrice
//
//  Created by Léon Becker on 11.08.21.
//

import Combine
import Foundation

class ApiClient {
    func request<T: Decodable>(request: URLRequest) -> AnyPublisher<T, Error> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .eraseToAnyPublisher()
    }
}
