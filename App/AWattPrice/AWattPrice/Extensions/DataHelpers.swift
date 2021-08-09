//
//  DataHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.02.21.
//

import Foundation

/// Quickly json encode a value. Function will output errors through Logger. For custom handling of the specifc error which occurred, don't use this.
func quickJSONEncode<T: Encodable>(_ value: T, setEncoder: ((JSONEncoder) -> ())? = nil) -> Data? {
    let encoder = JSONEncoder()
    
    // Caller of this function could modify the JSONEncoder. For example: setting .dateEncodingStrategy.
    setEncoder?(encoder)
    
    do {
        let encodedData = try encoder.encode(value)
        return encodedData
    } catch {
        print("Couldn't encode value: \(error).")
        return nil
    }
}

///Quickly json decode a value. Function will output errors through Logger. For custom handling of the specifc error which occurred, don't use this.
func quickJSONDecode<T: Decodable>(_ data: Data, asType: T.Type, setDecoder: ((JSONDecoder) -> ())? = nil) -> T? {
    let decoder = JSONDecoder()
    
    setDecoder?(decoder)
    
    do {
        let data = try decoder.decode(asType, from: data)
        return data
    } catch {
        print("Couldn't decode encoded data: \(error).")
        return nil
    }
}
