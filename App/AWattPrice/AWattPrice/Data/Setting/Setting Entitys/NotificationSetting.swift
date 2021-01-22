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

/// Object which holds the current Setting object. Using NSFetchedResultsController the current setting stored in this object is updated if any changes occur to it.
class CurrentNotificationSetting: AutoUpdatingEntity<NotificationSetting> {
    /// Is set to true on the notification configuration page and is set to true if changes were made but not yet uploaded. This is used to not create to much data traffic.
    @Published var changesAndStaged = false
    /// If set to true it indicates to the app that the app is currently sending APNs configuration to the server (backend).
    @Published var currentlySendingToServer = NSLock()

    let pushNotificationUpdateManager: PushNotificationUpdateManager

    init(backendComm: BackendCommunicator, managedObjectContext: NSManagedObjectContext) {
        self.pushNotificationUpdateManager = PushNotificationUpdateManager(backendComm)
        super.init(entityName: "NotificationSetting", managedObjectContext: managedObjectContext)
    }

    /// Switches to new value for the setting which indicates if settings were changed but there was an error uploading these settings.
    func changeChangesButErrorUploading(newValue: Bool) {
        if entity != nil {
            if entity!.changesButErrorUploading != newValue {
                entity!.changesButErrorUploading = newValue

                do {
                    try managedObjectContext.save()
                } catch {
                    print("managedObjectContext failed to store new notification setting (changesButErrorUploading) attribute: \(error).")
                    return
                }
            }
        }
    }

    /* Changes the last stored APNs token to a new APNs token. A last stored APNs token should be only set if the server successfully could store the APNs token.
     - Parameter newValue: New last stored APNs token.
     */
    func changeLastApnsToken(newValue: String) {
        if entity != nil {
            if entity!.lastApnsToken != newValue {
                entity!.lastApnsToken = newValue

                do {
                    try managedObjectContext.save()
                } catch {
                    print("managedObjectContext failed to store new notification setting (lastApnsToken) attribute: \(error).")
                    return
                }
            }
        }
    }

    /// Get a push notification if the value drops below this locally stored selection.
    func changePriceBelowValue(newValue: Int) {
        if entity != nil {
            if entity!.priceBelowValue != newValue {
                entity!.priceBelowValue = newValue

                do {
                    try managedObjectContext.save()
                } catch {
                    print("managedObjectContext failed to store new notification setting (priceBelowValue) attribute: \(error).")
                    return
                }
            }
        }
    }

    /// Locally stores if the user will get a push notification when prices drop below a certain value.
    func changePriceDropsBelowValueNotifications(newValue: Bool) {
        if entity != nil {
            if entity!.priceDropsBelowValueNotification != newValue {
                entity!.priceDropsBelowValueNotification = newValue

                do {
                    try managedObjectContext.save()
                } catch {
                    print("managedObjectContext failed to store new notification setting (priceDropsBelowValueNotification) attribute: \(error).")
                    return
                }
            }
        }
    }
}
