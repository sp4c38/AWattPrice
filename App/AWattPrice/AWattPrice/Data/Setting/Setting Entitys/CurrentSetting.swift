//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import CoreData

class CurrentSetting: AutoUpdatingEntity<Setting> {
    @Published var currentVATToUse = GlobalAppSettings.VATAmount

    init(managedObjectContext: NSManagedObjectContext) {
        super.init(entityName: "Setting", managedObjectContext: managedObjectContext)
    }

//    /// This will check that when a tariff is selected that also a non-empty electricity price was set
//    func validateTariffAndEnergyPriceSet() {
//        if self.entity != nil {
//            if self.entity!.awattarTariffIndex > -1 {
//                if self.entity!.awattarBaseElectricityPrice == 0 {
//                    self.entity!.awattarTariffIndex = -1
//
//                    do {
//                        try self.managedObjectContext.save()
//                    } catch {
//                        print("Tried to change the awattar tariff index in Setting because no base electricity was given. This failed.")
//                    }
//                }
//            }
//        }
//    }

    func changeBaseElectricityCharge(newValue: Double) {
        changeSetting(self, isNew: { $0.awattarBaseElectricityPrice != newValue },
                      bySetting: { $0.awattarBaseElectricityPrice = newValue })
        }

    func changeAwattarTariffIndex(newValue: Int16) {
        changeSetting(self, isNew: { $0.awattarTariffIndex != newValue },
                      bySetting: { $0.awattarTariffIndex = newValue })
        }

    func changeCheapestTimeLastConsumption(newValue: Double) {
        changeSetting(self, isNew: { $0.cheapestTimeLastConsumption != newValue },
                      bySetting: { $0.cheapestTimeLastConsumption = newValue })
    }

    func changeCheapestTimeLastPower(newValue: Double) {
        changeSetting(self, isNew: { $0.cheapestTimeLastPower != newValue },
                      bySetting: { $0.cheapestTimeLastPower = newValue })
    }

    func changeTaxSelection(newValue: Bool) {
        changeSetting(self, isNew: { $0.pricesWithVAT != newValue },
                      bySetting: { $0.pricesWithVAT = newValue })
    }

    func changeRegionIdentifier(newValue: Int16) {
        changeSetting(self, isNew: { $0.regionIdentifier != newValue },
                      bySetting: { $0.regionIdentifier = newValue })
    }

    func changeShowWhatsNew(newValue: Bool) {
        changeSetting(self, isNew: { $0.showWhatsNew != newValue },
                      bySetting: { $0.showWhatsNew = newValue })
    }

    func changeSplashScreenFinished(newValue: Bool) {
        changeSetting(self, isNew: { $0.splashScreensFinished != newValue },
                      bySetting: { $0.splashScreensFinished = newValue })
    }
}
