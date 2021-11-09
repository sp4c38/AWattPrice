//
//  NotificationService+RemoteAccess.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Foundation
import UIKit

extension NotificationService {    
    func successfulRegisteredForRemoteNotifications(rawCurrentToken: Data, appSetting: CurrentSetting, notificationSetting: CurrentNotificationSetting) {
        logger.debug("Notification: Remote notifications granted with device token.")

        if let notificationSettingsEntity = notificationSetting.entity {
            let currentToken = rawCurrentToken.map {
                String(format: "%02.2hhx", $0)
            }.joined()
 
            var isNewToken = notificationSettingsEntity.forceUploadNotificationsOne || (notificationSettingsEntity.lastApnsToken != currentToken)
            
            if notificationSettingsEntity.forceUploadNotificationsOne {
                print("Notification: Force enabling uploading of notification config.")
                isNewToken = true
            }
            
            let onSuccess: () -> () = {
                if notificationSettingsEntity.forceUploadNotificationsOne == true {
                    DispatchQueue.main.async { notificationSetting.changeForceUploadNotificationsOne(to: false) }
                }
                self.pushState = .apnsRegistrationSuccessful
            }
            
            let onFailure: () -> () = {
                self.pushState = .apnsRegistrationFailed
            }
            
            if !isNewToken {
                print("Notification: Token isn't new, won't upload.")
                tokenContainer = TokenContainer(token: currentToken, nextUploadState: .doNothing)
                onSuccess()
            } else if isNewToken, notificationSettingsEntity.lastApnsToken == nil {
                print("Notification: New token but no old token, will parse new token on next notification request.")
                tokenContainer = TokenContainer(token: currentToken, nextUploadState: .addTokenTask)
                onSuccess()
            } else if isNewToken, notificationSettingsEntity.lastApnsToken != nil {
                if wantToReceiveAnyNotification(notificationSettingEntity: notificationSettingsEntity) {
                    print("Notification: New token, old token exists and want to receive at least one notification, uploading all notification config.")
                    tokenContainer = TokenContainer(token: currentToken, nextUploadState: .doNothing)
                    uploadAllNotificationConfig(appSetting: appSetting, notificationSetting: notificationSetting, onSuccess: onSuccess, onFailure: onFailure)
                } else {
                    print("Notification: New token, old token exists but don't want to receive any notification, uploading all config on next notification request.")
                    tokenContainer = TokenContainer(token: currentToken, nextUploadState: .uploadAllNotificationConfig)
                    onSuccess()
                }
            }
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
    
    func wantToReceiveAnyNotification(notificationSettingEntity: NotificationSetting) -> Bool {
        if notificationSettingEntity.priceDropsBelowValueNotification == true {
            return true
        } else {
            return false
        }
    }
    
    /// An attribute may not need to be uploaded to the server, for instance if no notifications are active. This function checks such cases.
    /// It is called when changing an notification related attribute that is tracked on the server. Only call it on attributes which won't trigger notifications to be enabled or disabled.
    /// - Parameters:
    ///   - upload: Function called if the attribute needs to be uploaded.
    ///   - noUpload: Function called if the attribute doesn't need to be uploaded.
    func changeUploadableAttribute(_ notificationSettingEntity: NotificationSetting, upload: @escaping () -> (), noUpload: @escaping () -> ()) {
        if wantToReceiveAnyNotification(notificationSettingEntity: notificationSettingEntity) {
            ensureAccess { access in
                if access {
                    upload()
                } else {
                    noUpload()
                }
            }
        } else {
            noUpload()
        }
    }
}
