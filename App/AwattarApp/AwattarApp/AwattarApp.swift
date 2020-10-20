//
//  AwattarAppApp.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import CoreData
import SwiftUI

class PersistenceManager {
    var persistentContainer: NSPersistentContainer {
        let container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores(completionHandler: { _, error in
            
            if let error = error {
                fatalError("Couldn't load persistent container. \(error)")
            }
        })
        
        return container
    }
}

@main
struct AwattarApp: App {
    var persistence = PersistenceManager()

    var body: some Scene {
        WindowGroup {
            TabNavigatorView()
                .environmentObject(AwattarData())
                .environmentObject(CurrentSetting(managedObjectContext: persistence.persistentContainer.viewContext))
        }
    }
}
