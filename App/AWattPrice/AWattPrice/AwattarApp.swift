//
//  AwattarAppApp.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import CoreData
import Network
import SwiftUI

class NetworkManager: ObservableObject {
    @Published var networkStatus: NWPath.Status = NWPath.Status.unsatisfied
    var monitorer: NWPathMonitor

    init() {
        self.monitorer = NWPathMonitor()
        self.monitorer.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.networkStatus = path.status
            }
        }
        self.monitorer.start(queue: DispatchQueue(label: "NetworkMonitorer"))
    }
}

struct NetworkManagerKey: EnvironmentKey {
    static var defaultValue: NetworkManager = NetworkManager()
}

extension EnvironmentValues {
    var networkManager: NetworkManager {
        get {
            return self[NetworkManagerKey.self]
        }
        set {}
    }
}

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
    var crtNotifiSetting: CurrentNotificationSetting
    var currentSetting: CurrentSetting
    
    var awattarData: AwattarData
    var keyboardObserver: KeyboardObserver
    
    init() {
        self.awattarData = AwattarData()
        self.crtNotifiSetting = CurrentNotificationSetting(managedObjectContext: self.persistence.persistentContainer.viewContext)
        self.currentSetting = CurrentSetting(managedObjectContext: self.persistence.persistentContainer.viewContext)
        self.keyboardObserver = KeyboardObserver()
        self.appDelegate.crtNotifiSetting = self.crtNotifiSetting
        self.appDelegate.currentSetting = self.currentSetting
    }
    
    var body: some Scene {
        WindowGroup {
            // The managedObjectContext from PersistenceManager mustn't be parsed to the views directly as environment value because views will only access it indirectly through CurrentSetting.
            
            ContentView()
                .environmentObject(awattarData)
                .environmentObject(currentSetting)
                .environmentObject(crtNotifiSetting)
                .environmentObject(CheapestHourManager())
                .environmentObject(keyboardObserver)
        }
    }
}
