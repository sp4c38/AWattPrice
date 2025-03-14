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
    @StateObject private var energyDataService = EnergyDataService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var cheapestHourManager = CheapestHourManager()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Simple flag to track if we've already configured the app
    @State private var hasConfigured = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(setting)
                .environmentObject(notificationSetting)
                .environmentObject(energyDataService)
                .environmentObject(notificationService)
                .environmentObject(cheapestHourManager)
                .onAppear {
                    // Only configure once
                    if !hasConfigured {
                        hasConfigured = true
                        configureApp()
                    }
                }
        }
    }
    
    private func configureApp() {
        // Assign all dependencies to the AppDelegate
        appDelegate.notificationService = notificationService
        appDelegate.setting = setting
        appDelegate.notificationSetting = notificationSetting
        
        // Use Task to call async methods during app initialization
        Task {
            _ = await notificationService.refreshAccessStates()
            
            if let selectedRegion = Region(rawValue: setting.entity.regionIdentifier) {
                try? await energyDataService.downloadAsync(region: selectedRegion)
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.networkManager) var networkManager
    @Environment(\.scenePhase) var scenePhase
    
    // Access environment objects
    @EnvironmentObject var setting: SettingCoreData
    @EnvironmentObject var notificationSetting: NotificationSettingCoreData
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var energyDataService: EnergyDataService

    @State var selectedTab = 1
    @State var shouldShowWhatsNew = false
    @State private var hasCheckedNotificationAccess = false
    @State private var isFirstLaunch = false

    var body: some View {
        VStack(spacing: 0) {
            if setting.entity.splashScreensFinished {
//                TabView(selection: $selectedTab) {
//                    SettingsPageView()
//                        .tabItem { Label("Settings", systemImage: "gear") }

                      PricesView()
                        .tag(1)
                        .tabItem { Label("Prices", systemImage: "bolt") }

//                    CheapestTimeView()
//                        .tabItem { Label("Cheapest Time", systemImage: "rectangle.and.text.magnifyingglass") }
//                }
//                .tint(Color(red: 0.87, green: 0.35, blue: 0.26))
//                .sheet(isPresented: $shouldShowWhatsNew) { WhatsNewPage() }
            } else {
                SplashScreenStartView()
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase, perform: scenePhaseChanged)
        .onAppear {
            // Check if we should show what's new screen
            shouldShowWhatsNew = AppContext.shared.checkShowWhatsNewScreen()
        }
    }
    
    /// Handles scene phase changes to perform appropriate actions
    func scenePhaseChanged(to scenePhase: ScenePhase) {
        guard scenePhase == .active else { return }
        
        // Reset badge number when app becomes active
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // Use Task to refresh data when becoming active
        Task {
            // Refreshes energy data if a region is selected
            if let selectedRegion = Region(rawValue: setting.entity.regionIdentifier) {
                try? await energyDataService.downloadAsync(region: selectedRegion)
            }
            
            // Refresh notification access state
            await refreshNotificationAccess()
        }
    }

    /// Refreshes notification access states if needed
    private func refreshNotificationAccess() async {
        _ = await notificationService.refreshAccessStates()
        hasCheckedNotificationAccess = true
    }
}
