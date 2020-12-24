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
