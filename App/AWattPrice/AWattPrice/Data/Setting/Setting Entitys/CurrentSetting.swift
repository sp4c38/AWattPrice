//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import CoreData

/// Object which holds the current Setting object. Using NSFetchedResultsController the current setting stored in this object is updated if any changes occur to it.
class CurrentSetting: AutoUpdatingEntity<Setting> {
    init(managedObjectContext: NSManagedObjectContext) {
        super.init(entityName: "Setting", managedObjectContext: managedObjectContext)
    }
    
    /// This will check that when a tariff is selected that also a non-empty electricity price was set
    func validateTariffAndEnergyPriceSet() {
        if self.entity != nil {
            if self.entity!.awattarTariffIndex > -1 {
                if self.entity!.awattarBaseElectricityPrice == 0 {
                    self.entity!.awattarTariffIndex = -1

                    do {
                        try self.managedObjectContext.save()
                    } catch {
                        print("Tried to change the awattar tariff index in Setting because no base electricity was given. This failed.")
                    }
                }
            }
        }
    }

    /*
    Changes the value if the splash screen is finished to the specified new value.
    - Parameter newValue: The new state to which the setting should be changed to.
    */
    func changeSplashScreenFinished(newValue: Bool) {
        if self.entity != nil {
            if self.entity!.splashScreensFinished != newValue {
                self.entity!.splashScreensFinished = newValue
            }

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new splashScreenFinished attribute: \(error).")
                return
            }
        }
    }

    /**
    Changes the value if prices are shown with tax/VAT included to the specified new value.
    - Parameter newValue: The new state to which the setting should be changed to.
    */
    func changeTaxSelection(newValue: Bool) {
        if self.entity != nil {
            if self.entity!.pricesWithTaxIncluded != newValue {
                self.entity!.pricesWithTaxIncluded = newValue
            }

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new pricesWithTaxIncluded attribute: \(error).")
                return
            }
        }
    }

    /**
    Changes the price of the base energy charge to the specified new value.
    - Parameter newValue: The new price to which the setting should be changed to.
    */
    func changeBaseElectricityCharge(newValue: Double) {
        if self.entity != nil {
            if self.entity!.awattarBaseElectricityPrice != newValue {
                self.entity!.awattarBaseElectricityPrice = newValue
            }

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new awattarBaseElectricityPrice attribute: \(error).")
                return
            }
        }
    }

    /**
    Changes the index of which energy profile/tariff is selected to the specified new index.
    - Parameter newValue: The new index to which the setting should be changed to.
    */
    func changeAwattarTariffIndex(newValue: Int16) {
        if self.entity != nil {
            if self.entity!.awattarTariffIndex != newValue {
                self.entity!.awattarTariffIndex = newValue
            }

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new awattarTariffIndex attribute: \(error).")
                return
            }
        }
    }

    /**
    Changes the last power usage setting which is used on the cheapest time page.
    - Parameter newValue: The new last power usage to which the setting should be changed to.
    */
    func changeCheapestTimeLastPower(newValue: Double) {
        if self.entity != nil {
            if self.entity!.cheapestTimeLastPower != newValue {
                self.entity!.cheapestTimeLastPower = newValue
            }

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new cheapestTimeLastPower attribute: \(error).")
                return
            }
        }
    }

    /* Changes the last total consumption setting which is used on the cheapest time page.
    - Parameter newValue: The new last power usage to which the setting should be changed to.
    */
    func changeCheapestTimeLastConsumption(newValue: Double) {
        if self.entity != nil {
            if self.entity!.cheapestTimeLastConsumption != newValue {
                self.entity!.cheapestTimeLastConsumption = newValue
            }

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new cheapestTimeLastConsumption attribute: \(error).")
                return
            }
        }
    }

    /* Changes the current region which is selected to get aWATTar prices.
    - Parameter newValue: The new region which was selected and to which this setting should be changed to.
    */
    func changeRegionSelection(newValue: Int16) {
        if self.entity != nil {
            if self.entity!.regionSelection != newValue {
                self.entity!.regionSelection = newValue
            }

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new regionSelection attribute: \(error).")
                return
            }
        }
    }
}
