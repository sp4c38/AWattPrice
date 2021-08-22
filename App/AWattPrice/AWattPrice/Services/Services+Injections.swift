//
//  Services+Injections.swift
//  AWattPrice
//
//  Created by Léon Becker on 21.08.21.
//

import Resolver

extension Resolver {
    public static func registerEntityManagers() {
        let persistenceManager = PersistenceManager()
        let viewContext = persistenceManager.persistentContainer.viewContext
        register { CurrentSetting(managedObjectContext: viewContext) }
            .scope(.application)
        register { CurrentNotificationSetting(managedObjectContext: viewContext) }
            .scope(.application)
    }
    
    public static func registerEnergyDataController() {
        register { EnergyDataController() }
            .scope(.application)
    }
    
    public static func registerNotificationService() {
        register { NotificationService() }
            .scope(.application)
    }
}
