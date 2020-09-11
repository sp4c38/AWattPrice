//
//  Settings+CoreDataProperties.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//
//

import Foundation
import CoreData


extension Settings {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Settings> {
        return NSFetchRequest<Settings>(entityName: "Settings")
    }

    @NSManaged public var awattarEnergyProfileIndex: Int16
    @NSManaged public var taxSelectionIndex: Int16

}

extension Settings : Identifiable {

}
