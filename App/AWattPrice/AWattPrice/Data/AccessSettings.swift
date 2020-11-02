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
        newSetting.awattarTariffIndex = -1
        newSetting.pricesWithTaxIncluded = true
        newSetting.awattarBaseElectricityPrice = 0
        newSetting.splashScreensFinished = false
        
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

/// Object which holds the current Setting object. Using NSFetchedResultsController the current setting stored in this object is updated if any changes occur to it.
class CurrentSetting: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    var managedObjectContext: NSManagedObjectContext // managed object context is stored with this object because it is later needed to change settings
    let settingController: NSFetchedResultsController<Setting> // settings controller which reports changes in the persistent stored Setting object
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        let fetchRequest = NSFetchRequest<Setting>(entityName: "Setting")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Setting.splashScreensFinished, ascending: true)]
        settingController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
            
        super.init()
        settingController.delegate = self
        do {
            try settingController.performFetch()
        } catch {
            print("Error performing fetch request on Setting-Item out of Core Data.")
        }
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        objectWillChange.send()
    }
    
    var setting: Setting? {
        // The current up-to-date Setting object. This variable is nil if any error occurred retrieving the Setting object.
        // It shouldn't happen that no Setting object is found because getSetting handles the case that there isn't any Setting object yet stored (which always happens on the first ever launch of the app).
        
        let currentSetting = getSetting(managedObjectContext: self.managedObjectContext, fetchRequestResults: settingController.fetchedObjects ?? []) ?? nil
        
        return currentSetting
    }
    
    /// This will check that when a tariff is selected that also a non-empty electricity price was set
    func validateTariffAndEnergyPriceSet() {
        if self.setting != nil {
            if self.setting!.awattarTariffIndex > -1 {
                if self.setting!.awattarBaseElectricityPrice == 0 {
                    self.setting!.awattarTariffIndex = -1
                    
                    
                    do {
                        try self.managedObjectContext.save()
                    } catch {
                        print("Tried to change the awattar tariff index in Setting because no base electricity was given. This failed.")
                    }
                }
            }
        }
    }
    
    /**
    Changes the state of if the splash screen is finished to the specified new state.
    - Parameter newState: The new state to which the setting should be changed to.
    */
    func changeSplashScreenFinished(newState: Bool) {
        if setting != nil {
            self.setting!.splashScreensFinished = newState

            do {
                try self.managedObjectContext.save()
            } catch {
                return
            }
        }
    }
    
    /**
    Changes the state of if prices are shown with tax/VAT included to the specified new state.
    - Parameter newTaxSelection: The new state to which the setting should be changed to.
    */
    func changeTaxSelection(newTaxSelection: Bool) {
        if setting != nil {
            self.setting!.pricesWithTaxIncluded = newTaxSelection
            
            do {
                try self.managedObjectContext.save()
            } catch {
                return
            }
        }
    }
    
    /**
    Changes the price of the base energy charge to the specified new state.
    - Parameter newBaseEnergyCharge: The new price to which the setting should be changed to.
    */
    func changeBaseElectricityCharge(newBaseElectricityCharge: Float) {
        if setting != nil {
            self.setting!.awattarBaseElectricityPrice = newBaseElectricityCharge

            do {
                try managedObjectContext.save()
            } catch {
                return
            }
        }
    }
    
    /**
    Changes the index of which energy profile/tariff is selected to the specified new index.
    - Parameter newProfileIndex: The new index to which the setting should be changed to.
    */
    func changeAwattarTariffIndex(newTariffIndex: Int16) {
        if setting != nil {
            self.setting!.awattarTariffIndex = newTariffIndex
            
            do {
                try managedObjectContext.save()
            } catch {
                return
            }
        }
    }
}
