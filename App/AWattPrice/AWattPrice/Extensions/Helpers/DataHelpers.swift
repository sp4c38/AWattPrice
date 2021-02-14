//
//  DataHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.02.21.
//

import Foundation

func jsonEncode<T: Encodable>(_ value: T, setEncoder: ((JSONEncoder) -> ())? = nil) -> Data? {
    let encoder = JSONEncoder()
    if setEncoder != nil {
        setEncoder!(encoder)
    }
    
    do {
        let encodedData = try encoder.encode(value)
        return encodedData
    } catch {
        return nil
    }
}

func jsonDecode<T: Decodable>(_ data: Data, asType: T.Type, setDecoder: ((JSONDecoder) -> ())? = nil) -> T? {
    let decoder = JSONDecoder()
    if setDecoder != nil {
        // Caller of this function could modify the jsonDecoder. For example: setting .dateDecodingStrategy.
        setDecoder!(decoder)
    }
    
    do {
        let data = try decoder.decode(asType, from: data)
        return data
    } catch {
        return nil
    }
}
