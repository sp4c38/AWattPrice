//
//  AppDelegate.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import SwiftUI
import UIKit

import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var backendComm: BackendCommunicator?
    var crtNotifiSetting: CurrentNotificationSetting?
    var currentSetting: CurrentSetting?
    var notificationAccess: NotificationAccess?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        return true
    }

    func applicationWillTerminate(_: UIApplication) {
        if crtNotifiSetting != nil {
            if crtNotifiSetting!.changesAndStaged == true {
                if crtNotifiSetting!.entity != nil {
                    if crtNotifiSetting!.entity!.changesButErrorUploading == false {
                        crtNotifiSetting!.changeChangesButErrorUploading(newValue: true)
                    }
                }
            }
        }
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registration from APNs for push notifications was granted.")

        let apnsDeviceTokenString = deviceToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()

        if crtNotifiSetting != nil, currentSetting != nil, backendComm != nil {
            crtNotifiSetting!.currentlySendingToServer.lock()

            if crtNotifiSetting!.entity != nil, currentSetting!.entity != nil {
                let notificationConfigRepresentable = UploadPushNotificationConfigRepresentable(
                    apnsDeviceTokenString,
                    Int(currentSetting!.entity!.regionIdentifier),
                    currentSetting!.entity!.pricesWithVAT ? 1 : 0,
                    crtNotifiSetting!.entity!
                )

                if notificationConfigRepresentable.checkUserWantsNotifications() == true ||
                    crtNotifiSetting!.entity!.changesButErrorUploading == true
                {
                    if crtNotifiSetting!.entity!.lastApnsToken != apnsDeviceTokenString ||
                        crtNotifiSetting!.entity!.changesButErrorUploading == true
                    {
                        DispatchQueue.global(qos: .background).async {
                            print("""
                                Need to update stored APNs configuration. Stored APNs token and current
                                APNs token mismatch OR previously notification configuration couldn't be
                                uploaded because of some issue.
                            """)
                            let group = DispatchGroup()
                            group.enter()
                            DispatchQueue.main.async {
                                self.crtNotifiSetting!.changeChangesButErrorUploading(newValue: false)
                                group.leave()
                            }
                            group.wait()
                            let requestSuccessful = self.backendComm!.uploadPushNotificationSettings(
                                configuration: notificationConfigRepresentable
                            )
                            if !requestSuccessful {
                                DispatchQueue.main.async {
                                    self.crtNotifiSetting!.changeChangesButErrorUploading(newValue: true)
                                }
                            }
                        }
                    } else {
                        print("No need to update stored APNs configuration. Stored token matches current APNs token and no errors previously occurred when uploading changes.")
                    }
                }
                crtNotifiSetting!.changeLastApnsToken(newValue: apnsDeviceTokenString)
            }
            crtNotifiSetting!.currentlySendingToServer.unlock()
        } else {
            print("Settings could not be found. Therefor can't store last APNs token.")
        }
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Registration to APNs for push notifications was NOT granted: \(error.localizedDescription)")
        if notificationAccess != nil {
            // App is allowed to send notification but failed to register for remote notifications.
            notificationAccess!.access = false
        }
    }
}
