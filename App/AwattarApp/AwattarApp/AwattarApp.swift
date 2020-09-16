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

class CurrentSetting: ObservableObject {
    @Published var setting: Setting? = nil
    
    func setSetting(managedObjectContext: NSManagedObjectContext) {
        let currentSetting = getSetting(managedObjectContext: managedObjectContext)
        self.setting = currentSetting!
    }
}

@main
struct AwattarApp: App {
    var persistence = PersistenceManager()
    
    
    var body: some Scene {
        WindowGroup {
            TabNavigatorView()
                .environment(\.managedObjectContext, persistence.persistentContainer.viewContext)
                .environmentObject(EnergyData())
                .environmentObject(CurrentSetting())
        }
    }
}
