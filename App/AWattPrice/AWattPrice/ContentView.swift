//
//  TabBar.swift
//  AWattPrice
//
//  Created by Léon Becker on 28.11.20.
//

import SwiftUI

/// Start of the application.
struct ContentView: View {
    @Environment(\.networkManager) var networkManager
    @Environment(\.scenePhase) var scenePhase

    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var currentSetting: CurrentSetting

    @ObservedObject var tabBarItems = TBItems()

    @State var initialAppearFinished: Bool? = false

    var body: some View {
        VStack {
            if currentSetting.entity != nil {
                VStack(spacing: 0) {
                    if currentSetting.entity!.splashScreensFinished == true {
                        ZStack {
                            HomeView()
                                .opacity(tabBarItems.selectedItemIndex == 0 ? 1 : 0)

                            CheapestTimeView()
                                .opacity(tabBarItems.selectedItemIndex == 1 ? 1 : 0)
                        }

                        Spacer(minLength: 0)

                        TabBar()
                            .environmentObject(tabBarItems)
                    } else {
                        SplashScreenStartView()
                    }
                }
                .onAppear {
                    initialAppearFinished = nil
                }
                .onChange(of: scenePhase) { newScenePhase in
                    if initialAppearFinished == nil {
                        initialAppearFinished = true
                        return
                    }
                }
                .onAppear {
                    // Check Show Whats New
                    if currentSetting.entity!.splashScreensFinished == false && currentSetting.entity!.showWhatsNew == true {
                        currentSetting.changeShowWhatsNew(newValue: false)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase) { newScenePhase in
            if newScenePhase == .active {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
}
