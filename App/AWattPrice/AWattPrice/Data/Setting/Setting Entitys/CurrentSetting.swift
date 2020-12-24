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

    /* Changes the last stored APNs token to a new APNs token. A last stored APNs token should be only set if the server successfully could store the APNs token.
    - Parameter newApnsToken: New last stored APNs token.
    */
    func changeLastApnsToken(newApnsToken: String) {
        if self.entity != nil {
            self.entity!.lastApnsToken = newApnsToken

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
        if self.entity != nil {
            self.entity!.splashScreensFinished = newState

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
        if self.entity != nil {
            self.entity!.pricesWithTaxIncluded = newTaxSelection

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
        if self.entity != nil {
            self.entity!.awattarBaseElectricityPrice = newBaseElectricityCharge

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
    - Parameter newProfileIndex: The new index to which the setting should be changed to.
    */
    func changeAwattarTariffIndex(newTariffIndex: Int16) {
        if self.entity != nil {
            self.entity!.awattarTariffIndex = newTariffIndex

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
    - Parameter newLastPower: The new last power usage to which the setting should be changed to.
    */
    func changeCheapestTimeLastPower(newLastPower: Double) {
        if self.entity != nil {
            self.entity!.cheapestTimeLastPower = newLastPower

            do {
                try self.managedObjectContext.save()
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
        if self.entity != nil {
            self.entity!.cheapestTimeLastConsumption = newLastConsumption

            do {
                try self.managedObjectContext.save()
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
        if self.entity != nil {
            self.entity!.regionSelection = newRegionSelection

            do {
                try self.managedObjectContext.save()
            } catch {
                print("managedObjectContext failed to store new regionSelection attribute: \(error).")
                return
            }
        }
    }
}
