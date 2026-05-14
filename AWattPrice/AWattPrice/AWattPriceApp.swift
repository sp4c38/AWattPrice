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
    @StateObject private var proSupporterStore = ProSupporterStore()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(energyDataService)
                .environmentObject(notificationService)
                .environmentObject(cheapestHourManager)
                .environmentObject(settingsManager)
                .environmentObject(proSupporterStore)
                .onAppear {
                    configureApp()
                    proSupporterStore.start()
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
    @EnvironmentObject var proSupporterStore: ProSupporterStore

    @State var selectedTab = 1
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

                    proSupporterView {
                        InsightsView()
                    } paywall: {
                        NavigationStack {
                            ProSupporterPaywallView(context: .insights)
                        }
                    }
                        .tag(2)
                        .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }

                    NavigationStack {
                        proSupporterView {
                            NotificationSettingView()
                        } paywall: {
                            ProSupporterPaywallView(context: .notifications)
                        }
                    }
                    .tag(3)
                    .tabItem { Label("Notifications", systemImage: "bell.badge") }
                }
                .tint(AppTheme.accent)
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

    @ViewBuilder
    private func proSupporterView<Content: View, Paywall: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder paywall: () -> Paywall
    ) -> some View {
        if proSupporterStore.hasPro {
            content()
        } else {
            paywall()
        }
    }
}
