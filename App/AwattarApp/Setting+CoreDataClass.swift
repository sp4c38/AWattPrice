//
//  Setting+CoreDataClass.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//
//

import Foundation
import CoreData

/**
 Core Data object to store variouse settings which can be modified by the user. In every way only one of this object should be stored. There must not exist multiple Setting objects in persitent storage because only one Setting object can be handled.
 */
@objc(Setting)
public class Setting: NSManagedObject {

}
