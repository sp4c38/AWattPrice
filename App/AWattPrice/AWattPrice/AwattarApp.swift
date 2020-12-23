//
//  AwattarAppApp.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import CoreData
import SwiftUI

/// An object which holds and loads a NSPersistentContainer to allow access to persistent stored data from Core Data.
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

/// Entry point of the app
@main
struct AwattarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var persistence = PersistenceManager()
    var currentSetting: CurrentSetting
    
    var awattarData: AwattarData
    var keyboardObserver: KeyboardObserver
    
    init() {
        awattarData = AwattarData()
        currentSetting = CurrentSetting(managedObjectContext: persistence.persistentContainer.viewContext)
        keyboardObserver = KeyboardObserver()
        appDelegate.currentSetting = currentSetting
    }
    
    var body: some Scene {
        WindowGroup {
            // The managedObjectContext from PersistenceManager mustn't be parsed to the views directly as environment value because views will only access it indirectly through CurrentSetting.
            
            ContentView()
                .environmentObject(awattarData)
                .environmentObject(currentSetting)
                .environmentObject(CheapestHourManager())
                .environmentObject(keyboardObserver)
        }
    }
}
