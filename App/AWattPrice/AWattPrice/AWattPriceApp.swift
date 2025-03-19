//
//  AWattPriceApp.swift
//  AWattPriceApp
//
//  Created by Léon Becker on 06.09.20.
//

import os
import SwiftUI
import SwiftData
import UserNotifications

class AppContext {
    static var shared = AppContext()
    
    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    func checkShowWhatsNewScreen() -> Bool {
        let savedVersion = UserDefaults.standard.string(forKey: "whatsNewScreenSavedAppVersion")
        let shouldShow = shouldShowWhatsNew(savedVersion: savedVersion)
        
        // Always save current version after check
        UserDefaults.standard.set(currentAppVersion, forKey: "whatsNewScreenSavedAppVersion")
        return shouldShow
    }
    
    private func shouldShowWhatsNew(savedVersion: String?) -> Bool {
        // No need to show if version hasn't changed
        guard savedVersion != currentAppVersion else {
            print("App version unchanged: \(currentAppVersion)")
            return false
        }
        
        // Show for version 2.0 or for 2.0.1 if coming from a version before 2.0
        let isTargetVersion = currentAppVersion == "2.0"
        let isUpdateToVersion = currentAppVersion == "2.0.1" && savedVersion != "2.0"
        
        if isTargetVersion || isUpdateToVersion {
            print("Showing 'What's New?' for update from \(savedVersion ?? "nil") to \(currentAppVersion)")
            return true
        }
        
        print("Version change doesn't qualify for 'What's New?' screen: \(savedVersion ?? "nil") to \(currentAppVersion)")
        return false
    }
}

@main
struct AWattPriceApp: App {
    // Get the shared SwiftData service
    private let swiftDataService = SwiftDataService.shared
    
    // Create state objects that will be shared throughout the app
    @StateObject private var energyDataService = EnergyDataService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var cheapestHourManager = CheapestHourManager()
    @StateObject private var settingsManager = SettingsManager.shared
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(energyDataService)
                .environmentObject(notificationService)
                .environmentObject(cheapestHourManager)
                .environmentObject(settingsManager)
                .onAppear {
                    configureApp()
                }
                .modelContainer(swiftDataService.modelContainer)
        }
    }
    
    private func configureApp() {
        // Assign all dependencies to the AppDelegate
        appDelegate.notificationService = notificationService
        appDelegate.setting = settingsManager.setting
    }
}

struct ContentView: View {
    @Environment(\.networkManager) var networkManager
    @Environment(\.scenePhase) var scenePhase
    
    // Access settings only through the manager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var energyDataService: EnergyDataService

    @State var selectedTab = 1
    @State var shouldShowWhatsNew = false
    
    var body: some View {
        VStack(spacing: 0) {
            if settingsManager.setting.onboarded {
                TabView(selection: $selectedTab) {
                    SettingsPageView()
                        .tabItem { Label("Settings", systemImage: "gear") }

                    PricesView()
                        .tag(1)
                        .tabItem { Label("Prices", systemImage: "bolt") }

                    CheapestTimeView()
                        .tabItem { Label("Cheapest Time", systemImage: "rectangle.and.text.magnifyingglass") }
                }
                .tint(Color(red: 0.87, green: 0.35, blue: 0.26))
                .sheet(isPresented: $shouldShowWhatsNew) { WhatsNewPage() }
            } else {
                SplashScreenStartView()
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            
            // Reset badge number
            UNUserNotificationCenter.current().setBadgeCount(0)
            
            Task {
                await notificationService.updateAccessStates()
            }
            
            energyDataService.download(region: settingsManager.setting.region, setting: settingsManager.setting)
        }
        .onAppear {
            // Check if we should show what's new screen
            shouldShowWhatsNew = AppContext.shared.checkShowWhatsNewScreen()
        }
    }
}
