//
//  AppDelegate.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import SwiftUI
import UserNotifications
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var notificationService: NotificationService!
    var setting: SettingCoreData!
    var notificationSetting: NotificationSettingCoreData!

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationService.successfulRegisteredForRemoteNotifications(rawCurrentToken: deviceToken, setting: setting, notificationSetting: notificationSetting)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notificationService.failedRegisteredForRemoteNotifications(error: error)
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Use notificationService as needed
        return true
    }
}
