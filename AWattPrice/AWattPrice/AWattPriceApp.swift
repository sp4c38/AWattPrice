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

enum AppDeepLinkDestination: String {
    case prices
    case insights
    case cheapestTime = "cheapest-time"

    init?(url: URL) {
        let route = url.host ?? url.pathComponents.dropFirst().first

        switch route {
        case Self.prices.rawValue:
            self = .prices
        case Self.insights.rawValue:
            self = .insights
        case Self.cheapestTime.rawValue:
            self = .cheapestTime
        default:
            return nil
        }
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
    @AppStorage("pendingDeepLinkDestination") private var pendingDeepLinkDestination = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if settingsManager.setting.onboarded {
                TabView(selection: $selectedTab) {
                    SettingsPageView()
                        .tag(0)
                        .tabItem { Label("Settings", systemImage: "gear") }

                    PricesView()
                        .tag(1)
                        .tabItem { Label("Prices", systemImage: "bolt") }

                    InsightsView()
                        .tag(2)
                        .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }

                    NavigationStack {
                        NotificationSettingView()
                    }
                    .tag(3)
                    .tabItem { Label("Notifications", systemImage: "bell.badge") }
                }
                .tint(AppTheme.accent)
                .sheet(isPresented: $shouldShowWhatsNew) { WhatsNewPage() }
            } else {
                SplashScreenStartView()
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshAppData()
        }
        .onAppear {
            // Check if we should show what's new screen
            shouldShowWhatsNew = AppContext.shared.checkShowWhatsNewScreen()
            refreshAppData()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func refreshAppData() {
        guard settingsManager.setting.onboarded else { return }

        // Reset badge number
        UNUserNotificationCenter.current().setBadgeCount(0)

        Task {
            await notificationService.updateAccessStates()
        }

        energyDataService.download(setting: settingsManager.setting)
    }

    private func handleDeepLink(_ url: URL) {
        guard let destination = AppDeepLinkDestination(url: url) else { return }

        switch destination {
        case .prices:
            selectedTab = 1
        case .insights:
            selectedTab = 2
        case .cheapestTime:
            pendingDeepLinkDestination = destination.rawValue
            selectedTab = 2
        }
    }
}
