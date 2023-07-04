//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import Combine
import CoreData

func getGeneralSettingEntity<T: NSManagedObject>(viewContext: NSManagedObjectContext, entityName: String, setDefaults: (T) -> ()) -> T {
    let settingsFetch = NSFetchRequest<T>(entityName: entityName)
    var settings: [T]
    do { settings = try viewContext.fetch(settingsFetch) }
    catch { fatalError("Couldn't fetch settings: \(error).") }
    
    var setting: T
    if let firstSetting = settings.first {
        setting = firstSetting
    } else {
        guard let description = NSEntityDescription.entity(forEntityName: entityName, in: viewContext) else {
            fatalError("Can't create NSEntityDescription for entity Name \(entityName).")
        }
        setting = T(entity: description, insertInto: viewContext)
        setDefaults(setting)
    }
    return setting
}

class SettingCoreData: ObservableObject {
    static let entityName = "Setting"
    
    let viewContext: NSManagedObjectContext
    @Published var entity: Setting
    
    var cancellables =  [AnyCancellable]()
    
    init(viewContext: NSManagedObjectContext) {
        let setting: Setting = getGeneralSettingEntity(viewContext: viewContext, entityName: Self.entityName, setDefaults: { newEntry in
            newEntry.cheapestTimeLastConsumption = 0
            newEntry.cheapestTimeLastPower = 0
            newEntry.pricesWithVAT = true
            newEntry.regionIdentifier = 0
            newEntry.splashScreensFinished = false
            newEntry.baseFee = 0
        })
        
        self.viewContext = viewContext
        self.entity = setting
        self.entity.objectWillChange.sink { _ in
            self.objectWillChange.send()
        }.store(in: &cancellables)
    }
}

class NotificationSettingCoreData: ObservableObject {
    static let entityName = "NotificationSetting"
    
    let viewContext: NSManagedObjectContext
    @Published var entity: NotificationSetting
    
    var cancellables =  [AnyCancellable]()
    
    init(viewContext: NSManagedObjectContext) {
        let setting: NotificationSetting = getGeneralSettingEntity(viewContext: viewContext, entityName: Self.entityName, setDefaults: { newEntry in
            newEntry.changesButErrorUploading = false
            newEntry.forceUpload = false
            newEntry.lastApnsToken = nil
            newEntry.priceBelowValue = 0
            newEntry.priceDropsBelowValueNotification = false
        })
        
        self.viewContext = viewContext
        self.entity = setting
        self.entity.objectWillChange.sink { _ in
            self.objectWillChange.send()
        }.store(in: &cancellables)
    }
}

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
                newEntry.splashScreensFinished = false
                newEntry.baseFee = 0
            }
        )
    }

    func changeCheapestTimeLastConsumption(to newValue: Double) {
        changeSetting(self, isNew: { $0.cheapestTimeLastConsumption != newValue }, bySetting: { $0.cheapestTimeLastConsumption = newValue })
    }

    func changeCheapestTimeLastPower(to newValue: Double) {
        changeSetting(self, isNew: { $0.cheapestTimeLastPower != newValue }, bySetting: { $0.cheapestTimeLastPower = newValue })
    }

    func changeTaxSelection(to newValue: Bool) {
        changeSetting(self, isNew: { $0.pricesWithVAT != newValue }, bySetting: { $0.pricesWithVAT = newValue })
    }

    func changeRegionIdentifier(to newValue: Int16) {
        changeSetting(self, isNew: { $0.regionIdentifier != newValue }, bySetting: { $0.regionIdentifier = newValue })
    }

    func changeSplashScreenFinished(to newValue: Bool) {
        changeSetting(self, isNew: { $0.splashScreensFinished != newValue }, bySetting: { $0.splashScreensFinished = newValue })
    }
    
    func changeBaseFee(to newValue: Double) {
        changeSetting(self, isNew: { $0.baseFee != newValue }, bySetting: { $0.baseFee = newValue })
    }
}
