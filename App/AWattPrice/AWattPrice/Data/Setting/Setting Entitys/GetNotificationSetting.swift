//
//  GetNotificationSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import CoreData

func getNotificationSetting(managedObjectContext: NSManagedObjectContext, fetchRequestResults: [NotificationSetting]) -> NotificationSetting? {
    if fetchRequestResults.count == 1 {
        // Settings file was found correctly
        return fetchRequestResults[0]
        
    } else if fetchRequestResults.count == 0 {
        // No Settings object is yet created. Create a new Settings object with default values and save it to the persistent store
        let newSetting = NotificationSetting(context: managedObjectContext)
        newSetting.getNewPricesAvailableNotification = false
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Error storing new settings object.")
            return nil
        }
        
        return newSetting
    } else {
        // Shouldn't happen because would mean that there are multiple Settings objects stored in the persistent storage
        // Only one should exist
        print("Multiple Settings objects found in persistent storage. This shouldn't happen with Settings objects. Will delete all Settings objects except of the last which is kept.")
        
        for x in 0...(fetchRequestResults.count - 1) {
            // Deletes all Settings objects except of the last
            if !(x == fetchRequestResults.count - 1) {
                managedObjectContext.delete(fetchRequestResults[x])
            }
        }
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Error storing new settings object.")
            return nil
        }
        
        return fetchRequestResults[fetchRequestResults.count - 1]
    }
}
