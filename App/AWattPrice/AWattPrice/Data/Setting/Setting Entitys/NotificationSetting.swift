//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import CoreData

//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import CoreData

class CurrentNotificationSetting: AutoUpdatingEntity<NotificationSetting> {
    /// Set to true if changes were made, but not yet uploaded.
    @Published var changesAndStaged = false
    /// Indication if app is currently sending APNs configuration to the backend.
    @Published var currentlySendingToServer = NSLock()

    let pushNotificationUpdateManager: PushNotificationUpdateManager

    init(backendComm: BackendCommunicator, managedObjectContext: NSManagedObjectContext) {
        pushNotificationUpdateManager = PushNotificationUpdateManager(backendComm)
        super.init(entityName: "NotificationSetting", managedObjectContext: managedObjectContext)
    }

    func changeChangesButErrorUploading(newValue: Bool) {
        changeSetting(self, isNew: { $0.changesButErrorUploading != newValue },
                      bySetting: { $0.changesButErrorUploading = newValue })
    }

    func changeLastApnsToken(to newValue: String) {
        changeSetting(self, isNew: { $0.lastApnsToken != newValue },
                      bySetting: { $0.lastApnsToken = newValue })
    }

    func changePriceBelowValue(to newValue: Int) {
        changeSetting(self, isNew: { $0.priceBelowValue != newValue },
                      bySetting: { $0.priceBelowValue = newValue })
    }

    func changePriceDropsBelowValueNotifications(to newValue: Bool) {
        changeSetting(self, isNew: { $0.priceDropsBelowValueNotification != newValue },
                      bySetting: { $0.priceDropsBelowValueNotification = newValue })
        }
}
