//
//  TabBar.swift
//  AWattPrice
//
//  Created by Léon Becker on 28.11.20.
//

import Resolver
import SwiftUI

/// Start of the application.
struct ContentView: View {
    @Environment(\.networkManager) var networkManager
    @Environment(\.scenePhase) var scenePhase

//    @EnvironmentObject var backendComm: BackendCommunicator
    @Injected var crtNotifiSetting: CurrentNotificationSetting
    @ObservedObject var currentSetting: CurrentSetting = Resolver.resolve()
//    @EnvironmentObject var notificationAccess: NotificationAccess

    @ObservedObject var tabBarItems = TBItems()

    @State var initialAppearFinished: Bool? = false

    var body: some View {
        VStack {
            if currentSetting.entity != nil {
                VStack(spacing: 0) {
                    if currentSetting.entity!.splashScreensFinished == true {
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
                .onAppear {
                    // Check Notification access
//                    if currentSetting.entity!.showWhatsNew == false && currentSetting.entity!.splashScreensFinished == true {
//                        managePushNotificationsOnAppAppear(
//                            notificationAccessRepresentable: notificationAccess, registerForRemoteNotifications: true
//                        ) {}
//                    }
                    initialAppearFinished = nil
                }
                .onChange(of: scenePhase) { newScenePhase in
                    if initialAppearFinished == nil {
                        initialAppearFinished = true
                        return
                    }
//                    if newScenePhase == .active, initialAppearFinished == true, currentSetting.entity!.showWhatsNew == false, currentSetting.entity!.splashScreensFinished == true {
//                        managePushNotificationsOnAppAppear(notificationAccessRepresentable: self.notificationAccess, registerForRemoteNotifications: false) {}
//                    }
                }
                .onAppear {
                    // Check Show Whats New
                    if currentSetting.entity!.splashScreensFinished == false && currentSetting.entity!.showWhatsNew == true {
                        currentSetting.changeShowWhatsNew(to: false)
                    }
                }
//                .onChange(of: crtNotifiSetting.entity!.changesButErrorUploading) { errorOccurred in
//                    if errorOccurred == true {
//                        backendComm.tryNotificationUploadAfterFailed(
//                            Int(currentSetting.entity!.regionIdentifier),
//                            currentSetting.entity!.pricesWithVAT ? 1 : 0,
//                            crtNotifiSetting,
//                            networkManager
//                        )
//                    }
//                }
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
