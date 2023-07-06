//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import Combine
import CoreData
import WidgetKit

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
    print("Retrieved setting for entity name: \(entityName).")
    return setting
}

class SettingCoreData: ObservableObject {
    static let entityName = "Setting"
    
    let viewContext: NSManagedObjectContext
    @Published var entity: Setting
    
    var cancellables =  [AnyCancellable]()
    
    init(viewContext: NSManagedObjectContext) {
        self.entity = getGeneralSettingEntity(viewContext: viewContext, entityName: Self.entityName, setDefaults: { newEntry in
            newEntry.cheapestTimeLastConsumption = 0
            newEntry.cheapestTimeLastPower = 0
            newEntry.pricesWithVAT = true
            newEntry.regionIdentifier = 0
            newEntry.splashScreensFinished = false
            newEntry.baseFee = 0
        })

        self.viewContext = viewContext
        self.entity.objectWillChange.sink { _ in
            self.objectWillChange.send()
        }.store(in: &cancellables)
    }
    
    /// Reloads the entity from the underlying SQLite file used by CoreData. This function should only be used when using different instances of this class at different locations. Different instances should only be used if the there are multiple targets using this class.
    ///
    /// Note: This will overwrite the staleness interval of the view context.
    func reloadEntity() {
        self.viewContext.stalenessInterval = 0
        self.viewContext.refresh(entity, mergeChanges: false)
    }
    
    func changeSetting(_ changeTask: @escaping (SettingCoreData) -> ()) {
        DispatchQueue.main.async {
            changeTask(self)
            do {
                try self.viewContext.save()
                WidgetCenter.shared.reloadTimelines(ofKind: pricesWidgetKind)
                print("Reloading prices widget timeline.")
            } catch {
                print("Couldn't save the view context: \(error).")
            }
        }
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
    
    func changeSetting(_ changeTask: (NotificationSettingCoreData) -> ()) {
        changeTask(self)
        do {
            try self.viewContext.save()
        } catch {
            print("Couldn't save the view context: \(error).")
        }
    }
}
