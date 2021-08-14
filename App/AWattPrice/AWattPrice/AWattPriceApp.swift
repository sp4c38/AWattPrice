//
//  AWattPriceApp.swift
//  AWattPriceApp
//
//  Created by Léon Becker on 06.09.20.
//

import CoreData
import os
import SwiftUI

public let logger = Logger()


/// Represents if AWattPrice has the permissions to send notifications.
class NotificationAccess: ObservableObject {
    @Published var access = false
}

@main
struct AWattPriceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let energyDataController = EnergyDataController()
    let crtNotifiSetting: CurrentNotificationSetting
    let currentSetting: CurrentSetting
    let notificationAccess: NotificationAccess
    let persistence = PersistenceManager()

    init() {
        crtNotifiSetting = CurrentNotificationSetting(managedObjectContext: persistence.persistentContainer.viewContext)
        currentSetting = CurrentSetting(
            managedObjectContext: persistence.persistentContainer.viewContext
        )
        
        if let entity = currentSetting.entity,
           let selectedRegion = Region(rawValue: entity.regionIdentifier)
        {
            energyDataController.download(region: selectedRegion)
        }
        
        notificationAccess = NotificationAccess()

        appDelegate.crtNotifiSetting = crtNotifiSetting
        appDelegate.currentSetting = currentSetting
        appDelegate.notificationAccess = notificationAccess
    }

    var body: some Scene {
        WindowGroup {
            // The managedObjectContext from PersistenceManager mustn't be parsed to the views directly as environment value because views will only access it indirectly through CurrentSetting.

            ContentView()
                .environmentObject(energyDataController)
                .environmentObject(currentSetting)
                .environmentObject(crtNotifiSetting)
                .environmentObject(CheapestHourManager())
                .environmentObject(notificationAccess)
        }
    }
}
