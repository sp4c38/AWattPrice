//
//  NotificationService.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Combine
import SwiftUI
import UserNotifications
import UIKit

class NotificationService: ObservableObject {
    enum AccessState {
        case unknown
        case notAsked
        case granted
        case rejected
    }
    
    enum PushState {
        case unknown
        case asked
        case apnsRegistrationSuccessful
        case apnsRegistrationFailed
    }

    var token: String? = nil
    
    // Published properties without private(set)
    @Published var accessState: AccessState = .unknown
    @Published var pushState: PushState = .unknown
    
    /// Try to receive the required notification access permissions and send the notification request.
    private func sendNotificationConfiguration(_ notificationConfiguration: NotificationConfiguration) async throws -> (data: Data, response: URLResponse)? {
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

    func notificationExample(
        for ruleType: NotificationRuleType,
        notificationConfiguration: NotificationConfiguration
    ) async throws -> NotificationExampleResponse? {
        guard let apiRequest = APIClient.createNotificationExampleRequest(
            ruleType: ruleType,
            notificationConfiguration: notificationConfiguration
        ) else {
            return nil
        }

        return try await APIClient().request(to: apiRequest)
    }
    
    func wantToReceiveAnyNotification(setting: Setting) -> Bool {
        setting.priceDropsBelowEnabled || setting.priceRisesAboveEnabled || setting.dailySummaryEnabled
    }
    
    /// Configure notifications with the provided configuration
    /// Returns the server response data if successful, nil if no upload was needed or access wasn't granted
    func changeNotificationConfiguration(_ notificationConfiguration: NotificationConfiguration, _ setting: Setting) async throws -> (data: Data, response: URLResponse)? {
        var notificationConfiguration = notificationConfiguration
        
        let wantsNotifications = wantToReceiveAnyNotification(setting: setting)

        if wantsNotifications {
            guard await ensureAccess(), let token = self.token else {
                print("Didn't get notification access.")
                return nil
            }

            if notificationConfiguration.token == nil {
                notificationConfiguration.token = token
            }
        } else {
            guard let existingToken = notificationConfiguration.token ?? self.token ?? setting.pushToken else {
                print("User disabled notifications and no token exists to update remotely.")
                return nil
            }
            notificationConfiguration.token = existingToken
        }

        guard notificationConfiguration.token != nil else {
            print("Didn't get notification access.")
            return nil
        }

        // Try to send the configuration
        do {
            return try await sendNotificationConfiguration(notificationConfiguration)
        } catch {
            print("Failed to send notification configuration: \(error)")
            throw error
        }
    }
}
