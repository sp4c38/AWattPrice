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
    var notificationService: NotificationService
    var currentSetting: CurrentSetting
    var crtNotifiSetting: CurrentNotificationSetting
    
    init(notificationService: NotificationService, currentSetting: CurrentSetting, crtNotifiSetting: CurrentNotificationSetting) {
        self.notificationService = notificationService
        self.currentSetting = currentSetting
        self.crtNotifiSetting = crtNotifiSetting
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        return true
    }

    func applicationWillTerminate(_: UIApplication) {
        if let entity = crtNotifiSetting.entity,
           crtNotifiSetting.changesAndStaged == true,
           entity.changesButErrorUploading == false
        {
            crtNotifiSetting.changeChangesButErrorUploading(to: true)
        }
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationService.registeredForRemoteNotifications(encodedToken: deviceToken)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notificationService.failedRegisteredForRemoteNotifications(error: error)
    }
}
