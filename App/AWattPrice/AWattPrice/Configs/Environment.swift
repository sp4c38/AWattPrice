//
//  Environment.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import Foundation

public enum GlobalAppSettings {
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Info.plist doesn't exist in project.")
        }
        return dict
    }()
    
    static var rootURLString: String {
        guard let rootURLString = Self.infoDictionary["ROOT_URL"] as? String else {
            fatalError("ROOT_URL setting wasn't set in .plist / .xcconfig file.")
        }

        return rootURLString
    }
}
