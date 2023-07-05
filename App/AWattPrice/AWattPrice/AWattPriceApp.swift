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

let internalAppGroupIdentifier = "group.me.space8.AWattPrice.internal"

extension Resolver: ResolverRegistering {
    public static func registerAllServices() {
        let viewContext = CoreDataService.shared.container.viewContext
        
        register { SettingCoreData(viewContext: viewContext) }
            .scope(.application)
        register { NotificationSettingCoreData(viewContext: viewContext) }
            .scope(.application)
        
        register { EnergyDataController() }
            .scope(.application)
        
        register { NotificationService() }
            .scope(.application)
    }
}

@main
struct AWattPriceApp: App {
    @Injected var setting: SettingCoreData
    @Injected var energyDataController: EnergyDataController
    @Injected var notificationService: NotificationService
    let cheapestHourManager = CheapestHourManager()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        appDelegate.notificationService = notificationService

        notificationService.refreshAccessStates()

        if let selectedRegion = Region(rawValue: setting.entity.regionIdentifier) {
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
