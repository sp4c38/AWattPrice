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

class SettingsOptions: ObservableObject {
    // Global used settings
    
    @Published var selectedTaxOption: Int = 0
}

@main
struct AwattarApp: App {
    var persistence = PersistenceManager()
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.persistentContainer.viewContext)
                .environmentObject(EnergyData())
                .environmentObject(SettingsOptions())
        }
    }
}
