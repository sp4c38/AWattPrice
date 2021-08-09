//
//  NSRegularExpression.swift
//  AwattarApp
//
//  Created by Léon Becker on 09.08.21.
//

import SwiftUI

extension NSRegularExpression {
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }
    
    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        let matches = firstMatch(in: string, options: [], range: range) != nil
        return matches
    }
}
