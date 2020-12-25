//
//  AppDelegate.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var crtNotifiSetting: CurrentNotificationSetting? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registration from APNs for push notifications was granted.")
        
        let apnsDeviceTokenString = deviceToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()
        
        if self.crtNotifiSetting != nil {
            self.crtNotifiSetting!.currentlySendingToServer.lock()
            if self.crtNotifiSetting!.entity != nil {
                if self.crtNotifiSetting!.entity!.lastApnsToken != apnsDeviceTokenString ||
                    self.crtNotifiSetting!.entity!.changesButErrorUploading == true {
                    DispatchQueue.global(qos: .background).async {
                        print("Need to update stored APNs configuration. Stored APNs token and current APNs token are not identical OR previously notification configuration couldn't be uploaded because of some issue.")
                        let group = DispatchGroup()
                        group.enter()
                        DispatchQueue.main.async {
                            self.crtNotifiSetting!.changeChangesButErrorUploading(newValue: false)
                            group.leave()
                        }
                        group.wait()
                        let notificationConfigRepresentable = UploadPushNotificationConfigRepresentable(
                            apnsDeviceTokenString,
                            self.crtNotifiSetting!.entity!.getNewPricesAvailableNotification
                        )
                        let requestSuccessful = uploadPushNotificationSettings(configuration: notificationConfigRepresentable)
                        self.crtNotifiSetting!.changeLastApnsToken(newValue: apnsDeviceTokenString)
                        print(requestSuccessful)
                        if !requestSuccessful {
                            DispatchQueue.main.async {
                                self.crtNotifiSetting!.changeChangesButErrorUploading(newValue: true)
                            }
                        }
                    }
                } else {
                    print("No need to update stored APNs configuration. Stored token and current APNs token are identical and no errors previously occurred when uploading changes.")
                }
            }
            self.crtNotifiSetting!.currentlySendingToServer.unlock()
        } else {
            print("Settings could not be found. Therefor can't store last APNs token.")
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Registration to APNs for push notifications was NOT granted: \(error.localizedDescription)")
    }
}
