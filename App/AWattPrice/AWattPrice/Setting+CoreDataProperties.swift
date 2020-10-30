//
//  Setting+CoreDataProperties.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//
//

import Foundation
import CoreData

extension Setting {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Setting> {
        return NSFetchRequest<Setting>(entityName: "Setting")
    }

    /// Index representing an energy tariff/profile
    @NSManaged public var awattarTariffIndex: Int16
    /// Boolean which sets if prices throughout the app will be calculated with or without VAT/tax included
    @NSManaged public var pricesWithTaxIncluded: Bool
    /// The base energy price which must be individually set by the user
    @NSManaged public var awattarBaseElectricityPrice: Float
    /// The splash screen must only be shown once. This persistent stored value ensures that this is the case.
    @NSManaged public var splashScreensFinished: Bool
}
