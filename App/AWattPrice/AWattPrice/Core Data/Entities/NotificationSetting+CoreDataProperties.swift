//
//  NotificationSettings+CoreDataProperties.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//
//

import CoreData
import Foundation

public extension NotificationSetting {
    @nonobjc class func fetchRequest() -> NSFetchRequest<NotificationSetting> {
        NSFetchRequest<NotificationSetting>(entityName: "NotificationSetting")
    }

    /// If this setting is true the app tried to upload certain notification settings (including token) but failed.
    /// This could happen if data sent to server was formatted wrong, if the user changed
    /// notification settings while the APNs token still was beeing uploaded or if there is no
    /// intnernet connection but notification settings (including token) were changed.
    @NSManaged var changesButErrorUploading: Bool
    /// Stores the last apns token that was sent to the Apps provider server.
    @NSManaged var lastApnsToken: String?
    /// Associated setting which is needed if priceDropsBelowNotification is active.
    /// The user will get push notifications if any energy prices are below this value.
    @NSManaged var priceBelowValue: Int
    /// If activated and configured by the user it will make sure that the user becomes
    /// a notification if there are prices below a certain value.
    @NSManaged var priceDropsBelowValueNotification: Bool
    /// Force upload notification configuration.
    @NSManaged var forceUpload: Bool
}
