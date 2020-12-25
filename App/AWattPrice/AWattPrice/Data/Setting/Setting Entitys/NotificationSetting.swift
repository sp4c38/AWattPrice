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
    
    init(managedObjectContext: NSManagedObjectContext) {
        super.init(entityName: "NotificationSetting", managedObjectContext: managedObjectContext)
    }
    
    /* Changes the last stored APNs token to a new APNs token. A last stored APNs token should be only set if the server successfully could store the APNs token.
    - Parameter newValue: New last stored APNs token.
    */
    func changeLastApnsToken(newValue: String) {
        if self.entity != nil {
            if self.entity!.lastApnsToken != newValue {
                self.entity!.lastApnsToken = newValue
            }

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new lastApnsToken attribute: \(error).")
                return
            }
        }
    }
    
    /// Switches to new value for the setting if the user should get a notification when new prices are available.
    func changeNewPricesAvailable(newValue: Bool) {
        if self.entity != nil {
            if self.entity!.getNewPricesAvailableNotification != newValue {
                self.entity!.getNewPricesAvailableNotification = newValue
            }
            
            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new notification setting (getNewPricesAvailableNotification) attribute: \(error).")
                return
            }
        }
    }
    
    /// Switches to new value for the setting which indicates if settings were changed but there was an error uploading these settings.
    func changeChangesButErrorUploading(newValue: Bool) {
        if self.entity != nil {
            if self.entity!.changesButErrorUploading != newValue {
                self.entity!.changesButErrorUploading = newValue
            } else {
                return
            }
            
            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new notification setting (getNewPricesAvailableNotification) attribute: \(error).")
                return
            }
            return
        }
    }
}
