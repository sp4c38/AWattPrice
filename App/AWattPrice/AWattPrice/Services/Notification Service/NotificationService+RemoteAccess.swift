//
//  NotificationService+RemoteAccess.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Foundation
import UIKit

extension NotificationService {    
    func successfulRegisteredForRemoteNotifications(rawCurrentToken: Data, setting: SettingCoreData, notificationSetting: NotificationSettingCoreData) {
        logger.debug("Notification: Remote notifications granted with device token.")

        let currentToken = rawCurrentToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()
        
        if notificationSetting.entity.lastApnsToken != currentToken, notificationSetting.entity.lastApnsToken != nil {
            Task {
                let notificationConfiguration = NotificationConfiguration.create(currentToken, setting, notificationSetting)
                do {
                    _ = try await changeNotificationConfiguration(notificationConfiguration, notificationSetting)
                } catch {
                    print("Failed to update notification configuration after token change: \(error)")
                }
            }
        }
        
        notificationSetting.changeSetting { $0.entity.lastApnsToken = currentToken }
        token = currentToken
        self.pushState = .apnsRegistrationSuccessful
    }
    
    func failedRegisteredForRemoteNotifications(error: Error) {
        print("Notification: Push notification registration not granted: \(error).")
        pushState = .apnsRegistrationFailed
    }
    
    func registerForRemoteNotifications() {
        if pushState == .unknown {
            self.pushState = .asked
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
