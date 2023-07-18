//
//  TabBar.swift
//  AWattPrice
//
//  Created by Léon Becker on 28.11.20.
//

import Combine
import Resolver
import SwiftUI

class ContentViewModel: ObservableObject {
    var setting: SettingCoreData = Resolver.resolve()
    var notificationSetting: NotificationSettingCoreData = Resolver.resolve()
    var notificationService: NotificationService = Resolver.resolve()
    
    var checkAccessStates = false
    
    var cancellables = [AnyCancellable]()
    
    init() {
        setting.objectWillChange.sink(receiveValue: { self.objectWillChange.send() }).store(in: &cancellables)
    }
    
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
                        }.store(in: &self.cancellables)
                    })
                }
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

struct ContentView: View {
    @Environment(\.networkManager) var networkManager
    @Environment(\.scenePhase) var scenePhase

    @State var tabSelection = 1
    @State var showWhatsNewScreen = false
    @StateObject var viewModel = ContentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.setting.entity.splashScreensFinished {
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
        .onChange(of: scenePhase, perform: viewModel.scenePhaseChanged)
        .onAppear {
            showWhatsNewScreen = AppContext.shared.checkShowWhatsNewScreen()
        }
    }
}
