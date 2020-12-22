//
//  PushNotificationManager.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import UIKit
import UserNotifications

func managePushNotificationsOnAppStart() {
    if checkNotificationAccess() == true {
        UIApplication.shared.registerForRemoteNotifications()
    } else {
    }
}
