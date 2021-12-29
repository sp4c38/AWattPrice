//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import CoreData

class CurrentSetting: AutoUpdatingSingleEntity<Setting> {
    init(managedObjectContext: NSManagedObjectContext) {
        super.init(
            entityName: "Setting",
            managedObjectContext: managedObjectContext,
            setDefaultValues: { newEntry in
                newEntry.cheapestTimeLastConsumption = 0
                newEntry.cheapestTimeLastPower = 0
                newEntry.pricesWithVAT = true
                newEntry.regionIdentifier = 0
                newEntry.showWhatsNew = false
                newEntry.splashScreensFinished = false
            }
        )
    }

    func changeCheapestTimeLastConsumption(to newValue: Double) {
        changeSetting(self, isNew: { $0.cheapestTimeLastConsumption != newValue },
                      bySetting: { $0.cheapestTimeLastConsumption = newValue })
    }

    func changeCheapestTimeLastPower(to newValue: Double) {
        changeSetting(self, isNew: { $0.cheapestTimeLastPower != newValue },
                      bySetting: { $0.cheapestTimeLastPower = newValue })
    }

    func changeTaxSelection(to newValue: Bool) {
        changeSetting(self, isNew: { $0.pricesWithVAT != newValue },
                      bySetting: { $0.pricesWithVAT = newValue })
    }

    func changeRegionIdentifier(to newValue: Int16) {
        changeSetting(self, isNew: { $0.regionIdentifier != newValue },
                      bySetting: { $0.regionIdentifier = newValue })
    }

    func changeShowWhatsNew(to newValue: Bool) {
        changeSetting(self, isNew: { $0.showWhatsNew != newValue },
                      bySetting: { $0.showWhatsNew = newValue })
    }

    func changeSplashScreenFinished(to newValue: Bool) {
        changeSetting(self, isNew: { $0.splashScreensFinished != newValue },
                      bySetting: { $0.splashScreensFinished = newValue })
    }
}
