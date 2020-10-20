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

    @NSManaged public var splashScreensFinished: Bool
    @NSManaged public var awattarEnergyProfileIndex: Int16
    @NSManaged public var pricesWithTaxIncluded: Bool
    @NSManaged public var awattarEnergyPrice: Float

}
