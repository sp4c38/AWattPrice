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

    /// If this setting is true the app tried to upload certain notification settings (including token) but failed. This could happen if data sent to server was formatted wrong, if the user changed notification settings while the APNs token still was beeing uploaded or if there is no intnernet connection but notification settings (including token) were changed.
    @NSManaged public var changesButErrorUploading: Bool
    /// Stores the last apns token that was sent to the Apps provider server.
    @NSManaged public var lastApnsToken: String?
    /// Representing if the user wants to a notification when new prices are available.
    @NSManaged public var getNewPricesAvailableNotification: Bool

}
