//
//  CoreDataService.swift
//  AWattPrice
//
//  Created by Léon Becker on 06.07.23.
//

import CoreData
import Foundation

class CoreDataService {
    let container: NSPersistentContainer
    
    init?(name: String = "Model") {
        // The CoreData sqlite file is supposed to be located in the AWattPrice app group. Check if the sqlite file is already present in the app group. If it's only inside the app, move the file.

        let fileManager = FileManager.default
        let storeName = "\(name).sqlite"
        guard let appGroupDatabaseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: internalAppGroupIdentifier)?.appendingPathComponent(storeName) else {
            fatalError("Couldn't create container URL for app group with security application group identifier \(internalAppGroupIdentifier) and name \(name).")
        }
        
        let appGroupDatabaseExists = fileManager.fileExists(atPath: appGroupDatabaseURL.path)
        
        if !appGroupDatabaseExists {
            print("Database in app group doesn't exist yet.")
            return nil
        }
        
        print("A database file was found inside the app group container. Using this one.")
        self.container = NSPersistentContainer(name: name)
        container.persistentStoreDescriptions = [
            NSPersistentStoreDescription(url: appGroupDatabaseURL)
        ]
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error {
                fatalError("Couldn't load persistent container. \(error)")
            }
        })
    }
}
