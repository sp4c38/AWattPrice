//
//  StoreSettings.swift
//  AwattarApp
//
//  Created by Léon Becker on 12.09.20.
//

import CoreData
import Foundation

func getSetting(managedObjectContext: NSManagedObjectContext, fetchRequestResults: [Setting]) -> Setting? {
    if fetchRequestResults.count == 1 {
        // Settings file was found correctly
        return fetchRequestResults[0]
        
    } else if fetchRequestResults.count == 0 {
        // No Settings object is yet created. Create a new Settings object with default values and save it to the persistent store
        let newSetting = Setting(context: managedObjectContext)
        newSetting.lastApnsToken = nil
        newSetting.splashScreensFinished = false
        newSetting.regionSelection = 0
        newSetting.pricesWithTaxIncluded = true
        newSetting.awattarTariffIndex = -1
        newSetting.awattarBaseElectricityPrice = 0
        newSetting.cheapestTimeLastPower = 0
        newSetting.cheapestTimeLastConsumption = 0
        
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
