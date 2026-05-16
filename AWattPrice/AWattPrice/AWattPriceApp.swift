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
import UIKit

enum AppDeepLinkDestination: String {
    case prices
    case insights
    case cheapestTime = "cheapest-time"
    case pro

    init?(url: URL) {
        let route = url.host ?? url.pathComponents.dropFirst().first

        switch route {
        case Self.prices.rawValue:
            self = .prices
        case Self.insights.rawValue:
            self = .insights
        case Self.cheapestTime.rawValue:
            self = .cheapestTime
        case Self.pro.rawValue:
            self = .pro
        default:
            return nil
        }
    }
}

private enum ProPaywallTrigger: String, Identifiable {
    case insights
    case notifications
    case settings

    var id: String { rawValue }
}

private enum AppTabBarAppearance {
    static func apply() {
        let appearance = makeAppearance()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor.label
        UITabBar.appearance().unselectedItemTintColor = UIColor.label
    }

    static func apply(to tabBar: UITabBar) {
        let appearance = makeAppearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = UIColor.label
        tabBar.unselectedItemTintColor = UIColor.label
    }

    private static func makeAppearance() -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let selectedColor = UIColor.label
        let unselectedColor = UIColor.label
        let itemAppearances = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ]

        itemAppearances.forEach { itemAppearance in
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            itemAppearance.normal.iconColor = unselectedColor
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        }

        return appearance
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
        AppTabBarAppearance.apply()

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

    @State var selectedTab = 2
    @State private var activeProPaywallTrigger: ProPaywallTrigger?
    @AppStorage("pendingDeepLinkDestination") private var pendingDeepLinkDestination = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if settingsManager.setting.onboarded {
                TabView(selection: $selectedTab) {
                    SettingsPageView {
                        activeProPaywallTrigger = .settings
                    }
                        .tag(0)
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }

                    NavigationStack {
                        proSupporterView {
                            NotificationSettingView()
                        } paywall: {
                            ProLockedFeatureView(
                                title: "Notifications",
                                subtitle: "Pro unlocks price alerts and daily summaries when new electricity prices are available.",
                                systemImage: "bell.badge",
                                tint: .teal,
                                actionTitle: "Unlock Pro"
                            ) {
                                activeProPaywallTrigger = .notifications
                            }
                        }
                    }
                    .tag(1)
                    .tabItem { Label("Notifications", systemImage: "bell.badge") }

                    PricesView {
                        activeProPaywallTrigger = .settings
                    }
                        .tag(2)
                        .tabItem { Label("Prices", systemImage: "bolt") }

                    NavigationStack {
                        proSupporterView {
                            InsightsView()
                        } paywall: {
                            ProLockedFeatureView(
                                title: "Insights",
                                subtitle: "Advanced insights help you plan around cheap hours, expensive peaks, and renewable energy mix.",
                                systemImage: "chart.bar.xaxis",
                                tint: .blue,
                                actionTitle: "Unlock Pro"
                            ) {
                                activeProPaywallTrigger = .insights
                            }
                        }
                    }
                    .tag(3)
                    .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
                }
                .tint(.primary)
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
        .sheet(item: $activeProPaywallTrigger) { _ in
            NavigationStack {
                ProSupporterPaywallView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: activeProPaywallTrigger) { _, newValue in
            guard newValue == nil else { return }
            restoreTabBarColors()
        }
    }

    private func restoreTabBarColors() {
        AppTabBarAppearance.apply()

        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                updateTabBars(in: window)
            }
    }

    private func updateTabBars(in view: UIView) {
        if let tabBar = view as? UITabBar {
            AppTabBarAppearance.apply(to: tabBar)
        }

        view.subviews.forEach(updateTabBars)
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
            selectedTab = 2
        case .insights:
            selectedTab = 3
        case .cheapestTime:
            pendingDeepLinkDestination = destination.rawValue
            selectedTab = 3
        case .pro:
            activeProPaywallTrigger = .settings
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

private struct ProLockedFeatureView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ScrollView {
            AppCard(cornerRadius: 20, padding: 22, spacing: 18) {
                VStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 72, height: 72)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Text(subtitle.localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                Button(action: action) {
                    Text(actionTitle.localized())
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
        .navigationTitle(title.localized())
        .navigationBarTitleDisplayMode(.large)
    }
}
