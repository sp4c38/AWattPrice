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
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    @EnvironmentObject var currentSetting: CurrentSetting

    @ObservedObject var tabBarItems = TBItems()
    
    var body: some View {
        VStack {
            if currentSetting.entity != nil {
                VStack(spacing: 0) {
                    if currentSetting.entity!.splashScreensFinished == true {
                        ZStack {
                            HomeView()
                                .opacity(tabBarItems.selectedItemIndex == 0 ? 1 : 0)
                                    
                            ConsumptionComparisonView()
                                .opacity(tabBarItems.selectedItemIndex == 1 ? 1 : 0)
                                .environmentObject(tabBarItems)
                        }
                        .onAppear {
                            managePushNotificationsOnAppStart()
                        }
                        
                        Spacer(minLength: 0)
                        
                        TabBar()
                            .environmentObject(tabBarItems)
                    } else {
                        SplashScreenStartView()
                    }
                }
                .onChange(of: crtNotifiSetting.entity!.changesButErrorUploading) { newValue in
                    if newValue == true {
                        print("Detected changes to current notification configuration which could previously NOT be uploaded successful. Trying to upload again in background when network connection is satisfied and a APNs token was set.")
                        // If there were changes to the notification preferences but they couldn't be uploaded (e.g. no internet connection or other process currently uploading to server) than a background queue is initiated to take care of uploading these notification preferences as soon as no proces is currently sending to server and there is a internet connection.
                        
                        let resolveNotificationErrorUploadingQueue = DispatchQueue(label: "NotificationErrorUploadingQueue", qos: .background)
                        resolveNotificationErrorUploadingQueue.async {
                            crtNotifiSetting.currentlySendingToServer.lock()
                            while ((networkManager.networkStatus == .unsatisfied) || (crtNotifiSetting.entity!.lastApnsToken == nil)) {
                                // Only run further if the network connection is satisfied
                                sleep(1)
                            }
                            let notificationConfig = UploadPushNotificationConfigRepresentable(
                                crtNotifiSetting.entity!.lastApnsToken!,
                                crtNotifiSetting.entity!.getNewPricesAvailableNotification)
                            let requestSuccessful = uploadPushNotificationSettings(configuration: notificationConfig)
                            if requestSuccessful {
                                print("Could successfuly upload notification configuration after previously an upload failed.")
                                crtNotifiSetting.entity!.changesButErrorUploading = false
                            } else {
                                print("Could still NOT upload notification configuration after previously also an upload failed.")
                            }
                            crtNotifiSetting.currentlySendingToServer.unlock()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}
