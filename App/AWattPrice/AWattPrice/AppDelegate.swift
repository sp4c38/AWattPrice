//
//  AppDelegate.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import Resolver
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @Injected var notificationService: NotificationService
    @Injected var appSetting: CurrentSetting
    @Injected var notificationSetting: CurrentNotificationSetting

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationService.successfulRegisteredForRemoteNotifications(rawCurrentToken: deviceToken, appSetting: appSetting, notificationSetting: notificationSetting)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notificationService.failedRegisteredForRemoteNotifications(error: error)
    }
}
