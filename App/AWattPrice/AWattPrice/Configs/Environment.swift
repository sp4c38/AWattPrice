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
    
    static var VATAmount: Double {
        guard let VATAmountString = Self.infoDictionary["VAT_AMOUNT"] as? String else {
            fatalError("VAR_AMOUNT setting wasn't set in .plist / .xcconfig file.")
        }
        guard let VATAmountDouble = Double(VATAmountString) else {
            fatalError("VAT_AMOUNT which is specified in .plist / .xcconfig file is no valid Double.")
        }
        
        return VATAmountDouble
    }
}
