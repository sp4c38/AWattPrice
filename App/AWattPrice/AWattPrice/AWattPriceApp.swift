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
        
        notificationService.refreshAccessStates()
        if let selectedRegion = Region(rawValue: setting.entity.regionIdentifier) {
            energyDataService.download(region: selectedRegion)
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
    
    // Store cancellables directly in the view
    @State private var cancellables = Set<AnyCancellable>()

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
        
        // Handle first activation differently
        if !isFirstLaunch {
            isFirstLaunch = true
        } else {
            // Refresh data when returning to active state
            refreshEnergyDataIfNeeded()
        }
        
        // Handle notification configuration
        handleNotificationConfiguration()
    }
    
    /// Refreshes energy data if a region is selected
    private func refreshEnergyDataIfNeeded() {
        guard let selectedRegion = Region(rawValue: setting.entity.regionIdentifier) else { return }
        energyDataService.download(region: selectedRegion)
    }
    
    /// Handles notification configuration and access states
    private func handleNotificationConfiguration() {
        let processForceUpload = {
            guard self.notificationSetting.entity.forceUpload else { return }
            
            let notificationConfiguration = NotificationConfiguration.create(nil, self.setting, self.notificationSetting)
            self.notificationService.changeNotificationConfiguration(notificationConfiguration, self.notificationSetting, uploadStarted: { publisher in
                publisher
                    .sink { completion in
                        if case .finished = completion {
                            self.notificationSetting.changeSetting { $0.entity.forceUpload = false }
                        }
                    } receiveValue: { _ in }
                    .store(in: &self.cancellables)
            })
        }
        
        if hasCheckedNotificationAccess {
            notificationService.refreshAccessStates { _ in processForceUpload() }
        } else {
            processForceUpload()
            hasCheckedNotificationAccess = true
        }
    }
}
