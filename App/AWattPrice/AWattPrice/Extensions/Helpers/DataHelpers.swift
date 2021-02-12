//
//  DataHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.02.21.
//

import Foundation

func decodeJSONResponse<T: Decodable>(_ data: Data, asType: T.Type) -> T? {
    let jsonDecoder = JSONDecoder()
    jsonDecoder.dateDecodingStrategy = .secondsSince1970
    do {
        let decodedData = try jsonDecoder.decode(asType, from: data)
        return decodedData
    } catch {
        return nil
    }
}
