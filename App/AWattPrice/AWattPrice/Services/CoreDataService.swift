//
//  CoreDataService.swift
//  AWattPrice
//
//  Created by Léon Becker on 06.07.23.
//

import CoreData
import Foundation
import WidgetKit

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
