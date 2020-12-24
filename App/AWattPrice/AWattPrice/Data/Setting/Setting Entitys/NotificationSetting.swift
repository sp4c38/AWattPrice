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
    init(managedObjectContext: NSManagedObjectContext) {
        super.init(entityName: "NotificationSetting", managedObjectContext: managedObjectContext)
    }
    
    /* Changes the last stored APNs token to a new APNs token. A last stored APNs token should be only set if the server successfully could store the APNs token.
    - Parameter newValue: New last stored APNs token.
    */
    func changeLastApnsToken(newValue: String) {
        if self.entity != nil {
            self.entity!.lastApnsToken = newValue

            do {
                try self.managedObjectContext.save()
                print("Successfully stored new last apns token.")
            } catch {
                print("managedObjectContext failed to store new lastApnsToken attribute: \(error).")
                return
            }
        }
    }
    
    /// Switches to new value for the setting if the user should get a notification when new prices are available.
    func changeNewPricesAvailable(newValue: Bool) {
        if self.entity != nil {
            self.entity!.getNewPricesAvailableNotification = newValue
            
            do {
                try managedObjectContext.save()
                print("Successfully stored new notification setting (getNewPricesAvailableNotification).")
            } catch {
                print("managedObjectContext failed to store new notification setting (getNewPricesAvailableNotification) attribute: \(error).")
                return
            }
        }
    }
    
}
