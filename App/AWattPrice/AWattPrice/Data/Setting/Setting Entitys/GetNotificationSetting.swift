//
//  GetNotificationSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import CoreData

func getNotificationSetting(entityName _: String, managedObjectContext: NSManagedObjectContext, fetchRequestResults: [NotificationSetting]) -> NotificationSetting? {
    if fetchRequestResults.count == 1 {
        // Settings file was found correctly
        return fetchRequestResults[0]

    } else if fetchRequestResults.count == 0 {
        // No Settings object is yet created. Create a new Settings object with default values and save it to the persistent store
        if let entityDesciption = NSEntityDescription.entity(forEntityName: "NotificationSetting", in: managedObjectContext) {
            let newSetting = NotificationSetting(entity: entityDesciption, insertInto: managedObjectContext)
            newSetting.lastApnsToken = nil
            newSetting.changesButErrorUploading = false
            newSetting.priceDropsBelowValueNotification = false
            newSetting.priceBelowValue = 0

            do {
                try managedObjectContext.save()
            } catch {
                logger.error("Error storing new settings object: \(error.localizedDescription).")
                return nil
            }

            return newSetting
        } else {
            return nil
        }
    } else {
        logger.fault("""
            Multiple NotificationSetting objects found in persistent storage. This shouldn't happen with Settings objects.
            At any time, only one should exist. Will delete all Settings objects except of the last which is kept.
        """)

        for x in 0 ... (fetchRequestResults.count - 1) {
            // Deletes all Settings objects except of the last
            if !(x == fetchRequestResults.count - 1) {
                managedObjectContext.delete(fetchRequestResults[x])
            }
        }

        do {
            try managedObjectContext.save()
        } catch {
            logger.error("Error storing new settings object: \(error.localizedDescription).")
            return nil
        }

        return fetchRequestResults[fetchRequestResults.count - 1]
    }
}
