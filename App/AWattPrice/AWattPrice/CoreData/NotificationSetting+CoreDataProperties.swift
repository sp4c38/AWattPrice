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

    /// Stores the last apns token that was sent to the Apps provider server.
    @NSManaged public var lastApnsToken: String?
    /// Representing if the user wants to a notification when new prices are available.
    @NSManaged public var getNewPricesAvailableNotification: Bool

}
