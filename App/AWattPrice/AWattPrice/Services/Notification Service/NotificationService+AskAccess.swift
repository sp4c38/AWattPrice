//
//  NotificationService+AskAccess.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Combine
import UserNotifications

extension NotificationService {
    /// Gets the current notification settings asynchronously
    func updateAccessStates(registerPushAccess: Bool = true) async -> AccessState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            print("Notification: Notification access granted.")
            self.accessState = .granted
            if registerPushAccess {
                self.registerForRemoteNotifications()
            }
        case .notDetermined:
            print("Notification: Notification access wasn't asked for yet.")
            self.accessState = .notAsked
        default:
            print("Notification: Notification access not allowed: \(settings.authorizationStatus).")
            self.accessState = .rejected
        }
        
        return self.accessState
    }
    
    /// Requests notification access asynchronously
    func requestAccess(registerPushAccess: Bool = true) async -> AccessState {
        // Request authorization using the native async API
        do {
            let authGranted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification: Notification access failed with error: \(error).")
        }
        
        // Check the current state after request
        return await updateAccessStates(registerPushAccess: registerPushAccess)
    }
    
    /// Asynchronous function to ensure we have the required access for notifications
    func ensureAccess(ensurePushAccess: Bool = true) async -> Bool {
        if accessState == .rejected {
            return false  // Permission already denied, no need to continue
        }
        
        if accessState == .granted {
            if !ensurePushAccess {
                return true
            }
            
            // For push notifications, check push state
            if pushState == .apnsRegistrationSuccessful {
                return true  // Have all required permissions
            }
            
            if pushState == .apnsRegistrationFailed {
                return false // Push registration failed
            }
        }
        
        // Handle states requiring updates or requests
        if accessState == .unknown {
            _ = await updateAccessStates(registerPushAccess: false)
            return await ensureAccess(ensurePushAccess: ensurePushAccess)
        }

        if accessState == .notAsked {
            _ = await requestAccess(registerPushAccess: false)
            return await ensureAccess(ensurePushAccess: ensurePushAccess)
        }

        // Handle different push states
        switch pushState {
        case .unknown:
            registerForRemoteNotifications()
            return await ensureAccess(ensurePushAccess: true)
            
        case .asked:
            // Use withCheckedContinuation to wait for push state to update
            return await withCheckedContinuation { continuation in
                // Store the cancellable as a local variable that stays alive for this scope
                let cancellable = $pushState
                    .dropFirst()  // Skip the current value
                    .first()      // Take just the next value
                    .sink { newPushState in
                        if newPushState == .apnsRegistrationSuccessful {
                            continuation.resume(returning: true)
                        } else {
                            continuation.resume(returning: false)
                        }
                    }
                
                // Store the cancellable in a task-local variable to keep it alive
                // until the continuation completes
                Task {
                    // This task keeps the reference to cancellable alive
                    // until the continuation is resolved
                    _ = cancellable
                }
            }
        case .apnsRegistrationSuccessful:
            return true
        case .apnsRegistrationFailed:
            return false
        }
    }
}
