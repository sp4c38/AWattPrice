//
//  TabBar.swift
//  AWattPrice
//
//  Created by Léon Becker on 28.11.20.
//

import Resolver
import SwiftUI

class ContentViewModel: ObservableObject {
    var currentSetting: CurrentSetting = Resolver.resolve()
    var notificationSetting: CurrentNotificationSetting = Resolver.resolve()
    var notificationService: NotificationService = Resolver.resolve()
    
    var checkAccessStates = false
    
    func onAppear() {
        // Check Show Whats New
        if currentSetting.entity!.splashScreensFinished == false && currentSetting.entity!.showWhatsNew == true {
            currentSetting.changeShowWhatsNew(to: false)
        }
    }
    
    func scenePhaseChanged(to scenePhase: ScenePhase) {
        if scenePhase == .active {
            UIApplication.shared.applicationIconBadgeNumber = 0
            
            if checkAccessStates {
                notificationService.refreshAccessStates()
            } else { checkAccessStates = true }
    
            if notificationSetting.entity!.forceUpload {
                let notificationConfiguration = NotificationConfiguration.create(nil, currentSetting, notificationSetting)
                notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, uploadFinished: { self.notificationSetting.changeForceUpload(to: false) })
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.networkManager) var networkManager
    @Environment(\.scenePhase) var scenePhase

    @StateObject var viewModel = ContentViewModel()
    @ObservedObject var tabBarItems = TBItems()

    var body: some View {
        VStack {
            if viewModel.currentSetting.entity != nil {
                VStack(spacing: 0) {
                    if viewModel.currentSetting.entity!.splashScreensFinished {
                        ZStack {
                            SettingsPageView()
                                .opacity(tabBarItems.selectedItemIndex == 0 ? 1 : 0)

                            HomeView()
                                .opacity(tabBarItems.selectedItemIndex == 1 ? 1 : 0)

                            CheapestTimeView()
                                .opacity(tabBarItems.selectedItemIndex == 2 ? 1 : 0)
                        }

                        Spacer(minLength: 0)

                        TabBar()
                            .environmentObject(tabBarItems)
                    } else {
                        SplashScreenStartView()
                    }
                }
                .onAppear(perform: viewModel.onAppear)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase, perform: viewModel.scenePhaseChanged)
    }
}
