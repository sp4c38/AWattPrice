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
    var crtNotifiSetting: CurrentNotificationSetting? = nil
    var currentSetting: CurrentSetting? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
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
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registration from APNs for push notifications was granted.")
        
        let apnsDeviceTokenString = deviceToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()
        
        if self.crtNotifiSetting != nil && self.currentSetting != nil {
            self.crtNotifiSetting!.currentlySendingToServer.lock()

            if self.crtNotifiSetting!.entity != nil && self.currentSetting!.entity != nil {
                let notificationConfigRepresentable = UploadPushNotificationConfigRepresentable(
                    apnsDeviceTokenString,
                    Int(self.currentSetting!.entity!.regionIdentifier),
                    self.currentSetting!.entity!.pricesWithVAT ? 1 : 0,
                    self.crtNotifiSetting!.entity!)
                
                if notificationConfigRepresentable.checkUserWantsNotifications() == true || self.crtNotifiSetting!.entity!.changesButErrorUploading == true {
                    if self.crtNotifiSetting!.entity!.lastApnsToken != apnsDeviceTokenString ||
                        self.crtNotifiSetting!.entity!.changesButErrorUploading == true {
                        DispatchQueue.global(qos: .background).async {
                            print("Need to update stored APNs configuration. Stored APNs token and current APNs token mismatch OR previously notification configuration couldn't be uploaded because of some issue.")
                            let group = DispatchGroup()
                            group.enter()
                            DispatchQueue.main.async {
                                self.crtNotifiSetting!.changeChangesButErrorUploading(newValue: false)
                                group.leave()
                            }
                            group.wait()
                            let requestSuccessful = uploadPushNotificationSettings(configuration: notificationConfigRepresentable)
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
                self.crtNotifiSetting!.changeLastApnsToken(newValue: apnsDeviceTokenString)
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
