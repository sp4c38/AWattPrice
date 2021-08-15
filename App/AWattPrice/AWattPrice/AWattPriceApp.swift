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

@main
struct AWattPriceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let energyDataController = EnergyDataController()
    let notificationService = NotificationService()
    let crtNotifiSetting: CurrentNotificationSetting
    let currentSetting: CurrentSetting
    let persistence = PersistenceManager()
    let cheapestHourManager = CheapestHourManager()

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

        appDelegate.crtNotifiSetting = crtNotifiSetting
        appDelegate.currentSetting = currentSetting
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(energyDataController)
                .environmentObject(notificationService)
                .environmentObject(currentSetting)
                .environmentObject(crtNotifiSetting)
                .environmentObject(cheapestHourManager)
        }
    }
}
