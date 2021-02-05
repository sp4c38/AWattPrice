//
//  Environment.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import Foundation

public enum GlobalAppSettings {
    private static let appSettings: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Info.plist doesn't exist in project.")
        }
        guard let settingDict = dict["AWATTPRICE_VALUES"] else {
            fatalError("Info.plist doesn't contain the AWATTPRICE_VALUES dict.")
        }
        return settingDict as! [String: Any]
    }()
    
    static var awattpriceGroupID: String {
        guard let awattpriceGroupID = Self.appSettings["AWATTPRICE_GROUPID"] as? String else {
            fatalError("APP_GROUPID setting wasn't set in .plist / .xcconfig file.")
        }
        return awattpriceGroupID
    }

    static var rootURLString: String {
        guard let rootURLString = Self.appSettings["ROOT_URL"] as? String else {
            fatalError("ROOT_URL setting wasn't set in .plist / .xcconfig file.")
        }

        return rootURLString
    }

    static var VATAmount: Double {
        guard let VATAmountString = Self.appSettings["VAT_AMOUNT"] as? String else {
            fatalError("VAT_AMOUNT setting wasn't set in .plist / .xcconfig file.")
        }
        guard let VATAmountDouble = Double(VATAmountString) else {
            fatalError("VAT_AMOUNT which is specified in .plist / .xcconfig file is no valid Double.")
        }

        return VATAmountDouble
    }
}
