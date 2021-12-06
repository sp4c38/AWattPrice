//
//  NotificationService+RemoteAccess.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Foundation
import UIKit

extension NotificationService {    
    func successfulRegisteredForRemoteNotifications(rawCurrentToken: Data, currentSetting: CurrentSetting, notificationSetting: CurrentNotificationSetting) {
        logger.debug("Notification: Remote notifications granted with device token.")

        if let notificationSettingsEntity = notificationSetting.entity {
            let currentToken = rawCurrentToken.map {
                String(format: "%02.2hhx", $0)
            }.joined()
            
            if notificationSettingsEntity.lastApnsToken != currentToken, notificationSettingsEntity.lastApnsToken != nil {
                let notificationConfiguration = NotificationConfiguration.create(currentToken, currentSetting, notificationSetting)
                changeNotificationConfiguration(notificationConfiguration, notificationSetting, uploadFinished: nil, noUpload: nil)
            }
            
            notificationSetting.changeLastApnsToken(to: currentToken)
            token = currentToken
            self.pushState = .apnsRegistrationSuccessful
        } else {
            pushState = .apnsRegistrationFailed
        }
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
