//
//  PushNotificationManager.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import UIKit
import UserNotifications

func managePushNotificationsOnAppStart() {
    DispatchQueue.global(qos: .background).async {
        let notificationAccess = checkNotificationAccess()
        if notificationAccess == true {
            UIApplication.shared.registerForRemoteNotifications()
        } else {
        }
    }
}

func checkNotificationAccess() -> Bool {
    var returnResponse: Bool = false
    
    let dispatchSemaphore = DispatchSemaphore(value: 0)
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { successful, error in
        if successful == true && error == nil {
            print("Notification center access was granted.")
            returnResponse = true
        } else if successful == false && error == nil {
            print("Notification center acces was rejected.")
            returnResponse = false
        } else if error != nil {
            print("Notification center acces failed with error: \(error?.localizedDescription ?? "[Couldn't unpack error optional as localized description]").")
            returnResponse = false
        }

        dispatchSemaphore.signal()
    }
    dispatchSemaphore.wait()
    
    return returnResponse
}
