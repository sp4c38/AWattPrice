//
//  StoreSettings.swift
//  AwattarApp
//
//  Created by Léon Becker on 12.09.20.
//

import CoreData
import Foundation

func getTaxSettingsSelection(managedObjectContext: NSManagedObjectContext) -> Int {
    let fetchRequest: NSFetchRequest<Settings> = Settings.fetchRequest()
    var fetchRequestResults = [Settings]()
    
    do {
        fetchRequestResults = try managedObjectContext.fetch(fetchRequest)
    } catch {
        print("Couldn't read stored settings.")
        return 0
    }
    
    if fetchRequestResults.count == 1 {
        return Int(fetchRequestResults[0].taxSelectionIndex)
    } else if fetchRequestResults.count == 0 {
        // No Settings object is yet created. Create a new Settings object and save it to the persistent store
        let newSetting = Settings(context: managedObjectContext)
        newSetting.taxSelectionIndex = 0
        print("No Settings object yet stored. Creating new Settings object with default options.")
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Couldn't store new Settings object.")
        }
        
        return 0
    } else {
        // Shouldn't happen because would mean that there are multiple Settings objects stored in the persistent storages
        print("Multiple Settings objects found in persistent storage. This shouldn't happen with Settings objects. Will delete all Settings and will use last stored settings.")
        
        let oldTaxSelectionIndex = fetchRequestResults[fetchRequestResults.count - 1].taxSelectionIndex
        
        for storedSettingsObject in fetchRequestResults {
            managedObjectContext.delete(storedSettingsObject)
        }
    
        let newSetting = Settings(context: managedObjectContext)
        newSetting.taxSelectionIndex = oldTaxSelectionIndex
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Couldn't store new Settings object.")
        }
        
        return Int(oldTaxSelectionIndex)
    }
}

func storeTaxSettingsSelection(selectedTaxSetting: Int16, managedObjectContext: NSManagedObjectContext) {
    let fetchRequest: NSFetchRequest<Settings> = Settings.fetchRequest()
    var fetchRequestResults = [Settings]()
    
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
    
        let newSetting = Settings(context: managedObjectContext)
        newSetting.taxSelectionIndex = selectedTaxSetting
        
    } else if fetchRequestResults.count == 1 {
        let settingsObject = fetchRequestResults[0]
        settingsObject.taxSelectionIndex = selectedTaxSetting
        print("Stored new settings.")
        
    } else if fetchRequestResults.count == 0 {
        // No Settings object is yet created. Create a new Settings object and save it to the persistent store
        let newSetting = Settings(context: managedObjectContext)
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
