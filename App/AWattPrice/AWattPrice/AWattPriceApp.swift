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

class AppContext {
    static var shared = AppContext()
    
    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    func checkShowWhatsNewScreen() -> Bool {
        let savedVersion = UserDefaults.standard.string(forKey: "whatsNewScreenSavedAppVersion")

        if savedVersion != currentAppVersion, (currentAppVersion == "2.0" || (savedVersion != "2.0" && currentAppVersion == "2.0.1")) {
            print("Detected app version update from \(savedVersion ?? "nil (first app launch with version tracking") to 2.0 or 2.0.1. Showing \"What's New?\" screen for version 2.0 or 2.0.1.")
            UserDefaults.standard.set(currentAppVersion, forKey: "whatsNewScreenSavedAppVersion")
            return true
        } else {
            print("App version didn't change from last start or doesn't qualify for display of the \"What's New?\" screen. Current app version: \(currentAppVersion); saved app version: \(String(describing: savedVersion)).")
            UserDefaults.standard.set(currentAppVersion, forKey: "whatsNewScreenSavedAppVersion")
            return false
        }
    }
}

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
    @State private var isFirstLaunch = false

    var body: some View {
        VStack(spacing: 0) {
            if setting.entity.splashScreensFinished {
//                TabView(selection: $selectedTab) {
//                    SettingsPageView()
//                        .tabItem { Label("Settings", systemImage: "gear") }

//                      PricesView()
//                        .tag(1)
//                        .tabItem { Label("Pricesa", systemImage: "bolt") }

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
        
        // Reset badge number
        UIApplication.shared.applicationIconBadgeNumber = 0
        Task {
            await notificationService.updateAccessStates()
        }
        
        if let selectedRegion = Region(rawValue: setting.entity.regionIdentifier) {
            energyDataService.download(region: selectedRegion)
        }
    }
}
