//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import Combine
import CoreData
import WidgetKit

let internalAppGroupIdentifier = "group.me.space8.AWattPrice.internal"

class CoreDataService {
    static let shared = CoreDataService()
    
    let container: NSPersistentContainer
    
    init(name: String = "Model") {
        // The CoreData sqlite file is supposed to be located in the AWattPrice app group. Check if the sqlite file is already present in the app group. If it's only inside the app, move the file.

        let fileManager = FileManager.default
        let storeName = "\(name).sqlite"
        let appDatabaseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(storeName)
        
        guard let appGroupDatabaseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: internalAppGroupIdentifier)?.appendingPathComponent(storeName) else {
            fatalError("Couldn't create container URL for app group with security application group identifier \(internalAppGroupIdentifier) and name \(name).")
        }
        
        let appDatabaseExists = fileManager.fileExists(atPath: appDatabaseURL.path)
        let appGroupDatabaseExists = fileManager.fileExists(atPath: appGroupDatabaseURL.path)

        if !environmentIsMainApp() && !appGroupDatabaseExists {
            fatalError("The app hasn't yet moved its database to the app group.")
        }
        
        if appDatabaseExists && !appGroupDatabaseExists {
            print("No database was found in the app group container. Database was found inside the app container. It will now be moved to the app group...")
            let container = NSPersistentContainer(name: name)
            container.loadPersistentStores(completionHandler: { _, error in
                if let error = error {
                    fatalError("Couldn't load persistent container. \(error)")
                }
            })
            guard let persistentStore = container.persistentStoreCoordinator.persistentStore(for: appDatabaseURL) else {
                fatalError("Couldn't retrieve persistent store from persistent store coordinator for store url \(appDatabaseURL).")
            }
            do {
                _ = try container.persistentStoreCoordinator.migratePersistentStore(persistentStore, to: appGroupDatabaseURL, type: .sqlite)
                print("Successfully moved database from the app container to the app group container.")
                WidgetCenter.shared.reloadTimelines(ofKind: pricesWidgetKind)
            } catch {
                print("Couldn't move old database from the app container to the app group container.")
            }
        } else {
            print("A database file was found inside the app group container. Using this one.")
        }
        
        self.container = NSPersistentContainer(name: name)
        let storeDescription = NSPersistentStoreDescription(url: appGroupDatabaseURL)
        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error {
                fatalError("Couldn't load persistent container. \(error)")
            }
        })
    }
}

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
    /// Note: This will only refresh the entity from the persistent store if the viewContext.stalenessInterval was exceeded. Set the stalnessInterval accordingly if you wish to call this method. If the stalenessInterval isn't exceeded this method will reload from cache.
    func reloadEntity() {
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
