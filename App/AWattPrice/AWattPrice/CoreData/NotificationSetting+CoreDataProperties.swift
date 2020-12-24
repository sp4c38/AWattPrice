//
//  NotificationSettings+CoreDataProperties.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//
//

import Foundation
import CoreData


extension NotificationSetting {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NotificationSetting> {
        return NSFetchRequest<NotificationSetting>(entityName: "NotificationSetting")
    }

    /// Representing if the user wants to a notification when new prices are available.
    @NSManaged public var getNewPricesAvailableNotification: Bool

}
