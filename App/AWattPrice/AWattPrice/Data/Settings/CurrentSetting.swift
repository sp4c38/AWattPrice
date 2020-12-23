//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import CoreData

/// Object which holds the current Setting object. Using NSFetchedResultsController the current setting stored in this object is updated if any changes occur to it.
class CurrentSetting: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    var managedObjectContext: NSManagedObjectContext // managed object context is stored with this object because it is later needed to change settings
    let settingController: NSFetchedResultsController<Setting> // settings controller which reports changes in the persistent stored Setting object
    var setting: Setting?
    
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

        setting = getSetting(managedObjectContext: self.managedObjectContext, fetchRequestResults: settingController.fetchedObjects ?? []) ?? nil
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        objectWillChange.send()
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
    
    /* Changes the last stored APNs token to a new APNs token. A last stored APNs token should be only set if the server successfully could store the APNs token.
    - Parameter newApnsToken: New last stored APNs token.
    */
    func changeLastApnsToken(newApnsToken: String) {
        if setting != nil {
            self.setting!.lastApnsToken = newApnsToken
            
            do {
                try self.managedObjectContext.save()
                print("Successfully stored new last apns token.")
            } catch {
                print("managedObjectContext failed to store new lastApnsToken attribute: \(error).")
                return
            }
        }
    }
    
    /*
    Changes the state of if the splash screen is finished to the specified new state.
    - Parameter newState: The new state to which the setting should be changed to.
    */
    func changeSplashScreenFinished(newState: Bool) {
        if setting != nil {
            self.setting!.splashScreensFinished = newState

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new splashScreenFinished attribute: \(error).")
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
                print("managedObjectContext failed to store new pricesWithTaxIncluded attribute: \(error).")
                return
            }
        }
    }
    
    /**
    Changes the price of the base energy charge to the specified new state.
    - Parameter newBaseEnergyCharge: The new price to which the setting should be changed to.
    */
    func changeBaseElectricityCharge(newBaseElectricityCharge: Double) {
        if setting != nil {
            self.setting!.awattarBaseElectricityPrice = newBaseElectricityCharge

            do {
                try managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new awattarBaseElectricityPrice attribute: \(error).")
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
                print("managedObjectContext failed to store new awattarTariffIndex attribute: \(error).")
                return
            }
        }
    }
    
    /**
    Changes the last power usage setting which is used on the cheapest time page.
    - Parameter newLastPower: The new last power usage to which the setting should be changed to.
    */
    func changeCheapestTimeLastPower(newLastPower: Double) {
        if setting != nil {
            self.setting!.cheapestTimeLastPower = newLastPower
            
            do {
                try managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new cheapestTimeLastPower attribute: \(error).")
                return
            }
        }
    }
    
    /* Changes the last total consumption setting which is used on the cheapest time page.
    - Parameter newTimeLastPower: The new last power usage to which the setting should be changed to.
    */
    func changeCheapestTimeLastConsumption(newLastConsumption: Double) {
        if setting != nil {
            self.setting!.cheapestTimeLastConsumption = newLastConsumption
            
            do {
                try managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new cheapestTimeLastConsumption attribute: \(error).")
                return
            }
        }
    }
    
    /* Changes the current region which is selected to get aWATTar prices.
    - Parameter newRegionSelection: The new region which was selected and to which this setting should be changed to.
    */
    func changeRegionSelection(newRegionSelection: Int16) {
        if setting != nil {
            self.setting!.regionSelection = newRegionSelection
            
            do {
                try managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new regionSelection attribute: \(error).")
                return
            }
        }
    }
}
