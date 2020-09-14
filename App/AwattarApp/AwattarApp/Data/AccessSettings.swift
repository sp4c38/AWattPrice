//
//  StoreSettings.swift
//  AwattarApp
//
//  Created by Léon Becker on 12.09.20.
//

import CoreData
import Foundation

func getSetting(managedObjectContext: NSManagedObjectContext) -> Setting? {
    let fetchRequest: NSFetchRequest<Setting> = Setting.fetchRequest()
    var fetchRequestResults = [Setting]()
    
    do {
        fetchRequestResults = try managedObjectContext.fetch(fetchRequest)
    } catch {
        print("Couldn't read stored settings.")
        return nil
    }
    
    if fetchRequestResults.count == 1 {
        // Settings file was found correctly
        return fetchRequestResults[0]
        
    } else if fetchRequestResults.count == 0 {
        // No Settings object is yet created. Create a new Settings object and save it to the persistent store
        let newSetting = Setting(context: managedObjectContext)
        newSetting.awattarEnergyProfileIndex = 0
        newSetting.taxSelectionIndex = 0
        
        print("No Settings object yet stored. Creating new Settings object with default options.")
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Couldn't store new Settings object.")
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
            print("Couldn't store new Settings object.")
        }
        
        return fetchRequestResults[fetchRequestResults.count - 1]
    }
}

func storeTaxSettingsSelection(selectedTaxSetting: Int16, managedObjectContext: NSManagedObjectContext) {
    let fetchRequest: NSFetchRequest<Setting> = Setting.fetchRequest()
    var fetchRequestResults = [Setting]()
    
    do {
        fetchRequestResults = try managedObjectContext.fetch(fetchRequest)
    } catch {
        print("Couldn't read stored settings.")
        return
    }
    
    print("Run Store Tax Settings Selection.")
    
    if fetchRequestResults.count > 1 {
        // This shouldn't happen because it would mean that there are multiple Settings objects stored in the persistent storages
        print("Multiple Settings objects found in persistent storage. This shouldn't happen with Settings objects. Will delete all and will reset to default Settings.")
        
        for storedSettingsObject in fetchRequestResults {
            managedObjectContext.delete(storedSettingsObject)
        }
    
        let newSetting = Setting(context: managedObjectContext)
        newSetting.taxSelectionIndex = selectedTaxSetting
        
    } else if fetchRequestResults.count == 1 {
        let settingsObject = fetchRequestResults[0]
        settingsObject.taxSelectionIndex = selectedTaxSetting
        print("Stored new settings.")
        
    } else if fetchRequestResults.count == 0 {
        // No Settings object is yet created. Create a new Settings object and save it to the persistent store
        let newSetting = Setting(context: managedObjectContext)
        newSetting.taxSelectionIndex = selectedTaxSetting
        print("No Settings object yet stored. Creating new Settings object.")
    }
    
    do {
        try managedObjectContext.save()
    } catch {
        print("Error saving managed object context.")
        return
    }
}
