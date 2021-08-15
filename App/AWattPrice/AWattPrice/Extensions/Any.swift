//
//  Any.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Foundation

class AnyEncodable: Encodable {
    private let _coder: (Encoder) throws -> ()
    
    init<T: Encodable>(_ wrapped: T) {
        self._coder = wrapped.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _coder(encoder)
    }
}
