//
//  NotificationService+Requests.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Combine
import Foundation

extension NotificationService {
    /// Try to receive the required notification access permissions and send the notification request.
    func sendNotificationConfiguration(_ notificationConfiguration: NotificationConfiguration, _ notificationSetting: NotificationSettingCoreData) async throws -> (data: Data, response: URLResponse)? {
        guard accessState.value == .granted, pushState.value == .apnsRegistrationSuccessful else { return nil }
        
        guard let apiRequest = APIClient.createNotificationRequest(notificationConfiguration) else { return nil }
        
        do {
            let result = try await APIClient().request(to: apiRequest)
            print("Successfully sent notification task.")
            return result
        } catch {
            print("Couldn't sent notification tasks: \(error).")
            throw error
        }
    }
    
    func wantToReceiveAnyNotification(notificationSetting: NotificationSettingCoreData) -> Bool {
        if notificationSetting.entity.priceDropsBelowValueNotification == true {
            return true
        } else {
            return false
        }
    }
    
    func changeNotificationConfiguration(
        _ notificationConfiguration: NotificationConfiguration, _ notificationSetting: NotificationSettingCoreData, skipWantNotificationCheck: Bool = false,
        uploadStarted: ((Task<(data: Data, response: URLResponse)?, Error>) -> ())? = nil, cantStartUpload: (() -> ())? = nil, noUpload: (() -> ())? = nil
    ) {
        var notificationConfiguration = notificationConfiguration
        
        if skipWantNotificationCheck || wantToReceiveAnyNotification(notificationSetting: notificationSetting) {
            ensureAccess { access in
                if access, let token = self.token {
                    if notificationConfiguration.token == nil {
                        notificationConfiguration.token = token
                    }
                    
                    let task = Task { [self] in
                        return try await self.sendNotificationConfiguration(notificationConfiguration, notificationSetting)
                    }
                    
                    uploadStarted?(task)
                } else {
                    print("Didn't get notification access.")
                    cantStartUpload?()
                }
            }
        } else {
            print("User doesn't want to receive any notifications and thus don't need to upload.")
            noUpload?()
        }
    }
}
