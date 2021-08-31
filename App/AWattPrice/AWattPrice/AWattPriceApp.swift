//
//  AWattPriceApp.swift
//  AWattPriceApp
//
//  Created by Léon Becker on 06.09.20.
//

import CoreData
import os
import Resolver
import SwiftUI

public let logger = Logger()

extension Resolver: ResolverRegistering {
    public static func registerAllServices() {
        registerEntityManagers()
        registerEnergyDataController()
        registerNotificationService()
    }
}

@main
struct AWattPriceApp: App {
    @Injected var currentSetting: CurrentSetting
    @Injected var energyDataController: EnergyDataController
    @Injected var notificationService: NotificationService
    let cheapestHourManager = CheapestHourManager()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        appDelegate.notificationService = notificationService

        notificationService.refreshAccessStates()

        if let entity = currentSetting.entity,
           let selectedRegion = Region(rawValue: entity.regionIdentifier)
        {
            energyDataController.download(region: selectedRegion)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cheapestHourManager)
        }
    }
}
