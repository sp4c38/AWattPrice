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

    func presentNotificationExample(_ response: NotificationExampleResponse) async throws -> Bool {
        guard response.wouldSend, response.bodyLocKey != nil else { return false }
        guard await ensureAccess(ensurePushAccess: false) else { return false }

        let content = UNMutableNotificationContent()
        content.title = localizedNotificationText(key: response.titleLocKey, arguments: [])
        content.body = localizedNotificationText(key: response.bodyLocKey, arguments: response.locArgs)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "notification-example-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
        return true
    }

    func fallbackNotificationExample(for ruleType: NotificationRuleType) -> NotificationExampleResponse {
        switch ruleType {
        case .priceBelow:
            return NotificationExampleResponse(
                wouldSend: true,
                titleLocKey: "notifications.price_below.title",
                bodyLocKey: "notifications.price_below.body.example",
                locArgs: ["20", "14", "18"]
            )
        case .priceAbove:
            return NotificationExampleResponse(
                wouldSend: true,
                titleLocKey: "notifications.price_above.title",
                bodyLocKey: "notifications.price_above.body.example",
                locArgs: ["40", "18", "45"]
            )
        case .dailySummary:
            return NotificationExampleResponse(
                wouldSend: true,
                titleLocKey: "notifications.daily_summary.title",
                bodyLocKey: "notifications.daily_summary.body.example",
                locArgs: ["14", "18", "18", "45"]
            )
        }
    }

    private func localizedNotificationText(key: String?, arguments: [String]) -> String {
        guard let key else { return "" }
        return String(format: key.localized(), arguments: arguments.map { $0 as CVarArg })
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
