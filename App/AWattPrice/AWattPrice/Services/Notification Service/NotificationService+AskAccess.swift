//
//  NotificationService+AskAccess.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import UIKit
import UserNotifications

extension NotificationService {
    
    func registerForRemoteNotifications() {
        if !(pushNotificationState == .asked) {
            pushNotificationState = .asked
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func refreshAccessStates(onCompletion: (() -> ())? = nil) {
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                print("Notification: Notification access granted.")
                self.accessState = .granted
                self.registerForRemoteNotifications()
            case .notDetermined:
                print("Notification: Notification access wasn't asked for yet.")
                self.accessState = .notAsked
            default:
                print("Notification: Notification access not allowed: \(settings.authorizationStatus).")
                self.accessState = .rejected
            }
            if let onCompletion = onCompletion {
                onCompletion()
            }
        }
    }
    
    func requestAccess(onCompletion: (() -> ())? = nil) {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { authorizationGranted, error in
            if let error = error {
                print("Notification: Notification access failed with error: \(error).")
                return
            }
            self.refreshAccessStates(onCompletion: onCompletion)
        }
    }
}
