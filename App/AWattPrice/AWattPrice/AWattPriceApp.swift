//
//  AWattPriceApp.swift
//  AWattPriceApp
//
//  Created by Léon Becker on 06.09.20.
//

import CoreData
import os
import SwiftUI
import Combine

public let logger = Logger()

@main
struct AWattPriceApp: App {
    // Create state objects that will be shared throughout the app
    @StateObject private var setting = SettingCoreData(viewContext: CoreDataService.shared.container.viewContext)
    @StateObject private var notificationSetting = NotificationSettingCoreData(viewContext: CoreDataService.shared.container.viewContext)
    @StateObject private var energyDataController = EnergyDataController()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var cheapestHourManager = CheapestHourManager()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // One-time publisher for initialization
    private let appInitPublisher = Just(())
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(setting)
                .environmentObject(notificationSetting)
                .environmentObject(energyDataController)
                .environmentObject(notificationService)
                .environmentObject(cheapestHourManager)
                .onReceive(appInitPublisher) { _ in
                    configureApp()
                }
        }
    }
    
    private func configureApp() {
        // Assign all dependencies to the AppDelegate
        appDelegate.notificationService = notificationService
        appDelegate.setting = setting
        appDelegate.notificationSetting = notificationSetting
        
        notificationService.refreshAccessStates()
        if let selectedRegion = Region(rawValue: setting.entity.regionIdentifier) {
            energyDataController.download(region: selectedRegion)
        }
    }
}
