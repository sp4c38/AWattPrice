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
    
    static var awattpriceGroupID: String {
        guard let awattpriceGroupID = Self.infoDictionary["AWATTPRICE_GROUPID"] as? String else {
            fatalError("APP_GROUPID setting wasn't set in .plist / .xcconfig file.")
        }
        return awattpriceGroupID
    }

    static var rootURLString: String {
        guard let rootURLString = Self.infoDictionary["ROOT_URL"] as? String else {
            fatalError("ROOT_URL setting wasn't set in .plist / .xcconfig file.")
        }

        return rootURLString
    }

    static var currentVATAmount: Double {
        guard let VATAmountCurrentString = Self.infoDictionary["VAT_AMOUNT_CURRENT"] as? String else {
            fatalError("VAT_AMOUNT_CURRENT setting wasn't set in .plist / .xcconfig file.")
        }
        guard let VATAmountCurrentDouble = Double(VATAmountCurrentString) else {
            fatalError("VAT_AMOUNT_CURRENT which is specified in .plist / .xcconfig file is no valid Double.")
        }

        return VATAmountCurrentDouble
    }

    static var normalVATAmount: Double {
        guard let VATAmountNormalString = Self.infoDictionary["VAT_AMOUNT_NORMAL"] as? String else {
            fatalError("VAT_AMOUNT_NORMAL setting wasn't set in .plist / .xcconfig file.")
        }
        guard let VATAmountNormalDouble = Double(VATAmountNormalString) else {
            fatalError("VAT_AMOUNT_NORMAL which is specified in .plist / .xcconfig file is no valid Double.")
        }

        return VATAmountNormalDouble
    }
}
