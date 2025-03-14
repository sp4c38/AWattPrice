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
        guard accessState == .granted, pushState == .apnsRegistrationSuccessful else { return nil }
        
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
    
    /// Configure notifications with the provided configuration
    /// Returns the server response data if successful, nil if no upload was needed or access wasn't granted
    func changeNotificationConfiguration(
        _ notificationConfiguration: NotificationConfiguration, 
        _ notificationSetting: NotificationSettingCoreData
    ) async throws -> (data: Data, response: URLResponse)? {
        var notificationConfiguration = notificationConfiguration
        
        if !wantToReceiveAnyNotification(notificationSetting: notificationSetting) {
            print("User doesn't want to receive any notifications and thus don't need to upload.")
            return nil
        }

        let hasAccess = await ensureAccess()
        
        guard hasAccess, let token = self.token else {
            print("Didn't get notification access.")
            return nil
        }
        
        // Set token if needed
        if notificationConfiguration.token == nil {
            notificationConfiguration.token = token
        }
        
        // Try to send the configuration
        do {
            return try await sendNotificationConfiguration(notificationConfiguration, notificationSetting)
        } catch {
            print("Failed to send notification configuration: \(error)")
            throw error
        }
    }
}
