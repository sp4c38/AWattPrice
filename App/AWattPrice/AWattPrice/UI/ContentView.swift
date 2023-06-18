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
    var currentSetting: CurrentSetting = Resolver.resolve()
    var notificationSetting: CurrentNotificationSetting = Resolver.resolve()
    var notificationService: NotificationService = Resolver.resolve()
    
    var checkAccessStates = false
    
    var cancellables = [AnyCancellable]()
    
    init() {
        currentSetting.objectWillChange.sink(receiveValue: { self.objectWillChange.send() }).store(in: &cancellables)
    }
    
    func scenePhaseChanged(to scenePhase: ScenePhase) {
        if scenePhase == .active {
            UIApplication.shared.applicationIconBadgeNumber = 0
    
            let checkForceUpload = {
                if self.notificationSetting.entity!.forceUpload {
                    let notificationConfiguration = NotificationConfiguration.create(nil, self.currentSetting, self.notificationSetting)
                    self.notificationService.changeNotificationConfiguration(notificationConfiguration, self.notificationSetting, uploadStarted: { publisher in
                        publisher.sink { completion in
                            if case .finished = completion { self.notificationSetting.changeForceUpload(to: false) }
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

    @State var showWhatsNewScreen = false
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
                        .sheet(isPresented: $showWhatsNewScreen) { WhatsNewPage() }

                        Spacer(minLength: 0)

                        TabBar()
                            .environmentObject(tabBarItems)
                    } else {
                        SplashScreenStartView()
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase, perform: viewModel.scenePhaseChanged)
        .onAppear {
            showWhatsNewScreen = AppContext.shared.checkShowWhatsNewScreen()
        }
    }
}
