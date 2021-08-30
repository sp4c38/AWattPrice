//
//  NotificationService+RemoteAccess.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Foundation

extension NotificationService {
    func successfulRegisteredForRemoteNotifications(rawCurrentToken: Data) {
        logger.debug("Remote notifications granted with device token.")

        if let appSettingsEntity = appSettings.entity,
           let notificationSettingsEntity = notificationSettings.entity,
           let region = Region(rawValue: appSettingsEntity.regionIdentifier)
        {
            let currentToken = rawCurrentToken.map {
                String(format: "%02.2hhx", $0)
            }.joined()
            
            let isNewToken = notificationSettingsEntity.lastApnsToken != currentToken
            
            if !isNewToken {
                print("Notification: Token isn't new, won't upload.")
                tokenContainer = TokenContainer(token: currentToken, nextUploadState: .doNothing)
            } else if isNewToken, notificationSettingsEntity.lastApnsToken == nil {
                print("Notification: New token and no old token, will parse new token on next notification request.")
                tokenContainer = TokenContainer(token: currentToken, nextUploadState: .addTokenTask)
            } else if isNewToken, notificationSettingsEntity.lastApnsToken != nil {
                if wantToReceiveAnyNotification(notificationSettingEntity: notificationSettingsEntity) {
                    print("Notification: New token, old token exists and want to receive at least one notification, uploading all config now.")
                    tokenContainer = TokenContainer(token: currentToken, nextUploadState: .doNothing)
                    // UPLOAD EVERYTHING HERE
                } else {
                    print("Notification: New token, old token exists but don't want to receive any notification, uploading all config on next notification request.")
                    tokenContainer = TokenContainer(token: currentToken, nextUploadState: .uploadAllNotificationConfig)
                }
            }
            
            pushNotificationState = .apnsRegistrationSuccessful
        }
    }
    
    func failedRegisteredForRemoteNotifications(error: Error) {
        print("Notification: Push notification registration not granted: \(error).")
        pushNotificationState = .apnsRegistrationFailed
    }
}
