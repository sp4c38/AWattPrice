//
//  AwattarAppApp.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import CoreData
import SwiftUI

/// Represents if AWattPrice has the permissions to send notifications.
class NotificationAccess: ObservableObject {
    @Published var access = false
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

    let backendComm: BackendCommunicator
    let crtNotifiSetting: CurrentNotificationSetting
    let currentSetting: CurrentSetting
    let notificationAccess: NotificationAccess
    let persistence = PersistenceManager()

    init() {
        backendComm = BackendCommunicator()
        crtNotifiSetting = CurrentNotificationSetting(
            backendComm: backendComm,
            managedObjectContext: persistence.persistentContainer.viewContext
        )
        currentSetting = CurrentSetting(
            managedObjectContext: persistence.persistentContainer.viewContext
        )
        notificationAccess = NotificationAccess()

        appDelegate.backendComm = backendComm
        appDelegate.crtNotifiSetting = crtNotifiSetting
        appDelegate.currentSetting = currentSetting
        appDelegate.notificationAccess = notificationAccess
    }

    var body: some Scene {
        WindowGroup {
            // The managedObjectContext from PersistenceManager mustn't be parsed to the views directly as environment value because views will only access it indirectly through CurrentSetting.

            ContentView()
                .environmentObject(backendComm)
                .environmentObject(currentSetting)
                .environmentObject(crtNotifiSetting)
                .environmentObject(CheapestHourManager())
                .environmentObject(notificationAccess)
        }
    }
}
