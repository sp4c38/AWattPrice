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
    var notificationService: NotificationService!

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Notification serviced: \(notificationService)")
        notificationService.registeredForRemoteNotifications(rawNewToken: deviceToken)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Notification service: \(notificationService)")
        notificationService.failedRegisteredForRemoteNotifications(error: error)
    }
}
