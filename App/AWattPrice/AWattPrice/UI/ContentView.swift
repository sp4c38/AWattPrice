//
//  TabBar.swift
//  AWattPrice
//
//  Created by Léon Becker on 28.11.20.
//

import Combine
import SwiftUI

// Create a class to hold our cancellables - added ObservableObject conformance
private class CancellableStore: ObservableObject {
    var cancellables = Set<AnyCancellable>()
}

struct ContentView: View {
    @Environment(\.networkManager) var networkManager
    @Environment(\.scenePhase) var scenePhase
    
    // Access environment objects
    @EnvironmentObject var setting: SettingCoreData
    @EnvironmentObject var notificationSetting: NotificationSettingCoreData
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var energyDataController: EnergyDataController

    @State var tabSelection = 1
    @State var showWhatsNewScreen = false
    @State private var checkAccessStates = false
    @State private var hasProcessedFirstActivation = false
    
    // Store cancellables in a reference type object that can be mutated
    @StateObject private var cancellableStore = CancellableStore()

    var body: some View {
        VStack(spacing: 0) {
            if setting.entity.splashScreensFinished {
                TabView(selection: $tabSelection) {
                    SettingsPageView()
                        .tabItem { Label("Settings", systemImage: "gear") }

                    HomeView()
                        .tag(1)
                        .tabItem { Label("Prices", systemImage: "bolt") }

                    CheapestTimeView()
                        .tabItem { Label("Cheapest Time", systemImage: "rectangle.and.text.magnifyingglass") }
                }
                .tint(Color(red: 0.87, green: 0.35, blue: 0.26))
                .sheet(isPresented: $showWhatsNewScreen) { WhatsNewPage() }
            } else {
                SplashScreenStartView()
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase, perform: scenePhaseChanged)
        .onAppear {
            // Set up observation for setting changes if needed
            setting.objectWillChange
                .sink { _ in }
                .store(in: &cancellableStore.cancellables)
                
            showWhatsNewScreen = AppContext.shared.checkShowWhatsNewScreen()
        }
    }
    
    // Moved from ViewModel directly into the View
    func scenePhaseChanged(to scenePhase: ScenePhase) {
        if scenePhase == .active {
            UIApplication.shared.applicationIconBadgeNumber = 0
    
            let checkForceUpload = {
                if self.notificationSetting.entity.forceUpload {
                    let notificationConfiguration = NotificationConfiguration.create(nil, self.setting, self.notificationSetting)
                    self.notificationService.changeNotificationConfiguration(notificationConfiguration, self.notificationSetting, uploadStarted: { publisher in
                        publisher.sink { completion in
                            if case .finished = completion { self.notificationSetting.changeSetting { $0.entity.forceUpload = false } }
                        } receiveValue: { _ in
                        }.store(in: &self.cancellableStore.cancellables)
                    })
                }
            }
            
            // Only refresh data when becoming active if we've already processed first activation
            if hasProcessedFirstActivation {
                if let selectedRegion = Region(rawValue: setting.entity.regionIdentifier) {
                    energyDataController.download(region: selectedRegion)
                }
            } else {
                hasProcessedFirstActivation = true
            }
            
            if checkAccessStates {
                notificationService.refreshAccessStates { _ in checkForceUpload() }
            } else {
                checkForceUpload()
                checkAccessStates = true
            }
        }
    }
}
