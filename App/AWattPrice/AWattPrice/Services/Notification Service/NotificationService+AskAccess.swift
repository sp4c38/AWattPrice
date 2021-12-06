//
//  NotificationService+AskAccess.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Combine
import UserNotifications

extension NotificationService {
    func refreshAccessStates(registerPushAccess: Bool = true, onCompletion: ((AccessState) -> ())? = nil) {
        notificationCenter.getNotificationSettings { settings in
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
            
            onCompletion?(self.accessState)
        }
    }
    
    func requestAccess(registerPushAccess: Bool = true, onCompletion: ((AccessState) -> ())? = nil) {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
            if let error = error {
                print("Notification: Notification access failed with error: \(error).")
                return
            }
            self.refreshAccessStates(registerPushAccess: registerPushAccess, onCompletion: onCompletion)
        }
    }
    
    func ensureAccess(ensurePushAccess: Bool = true, forceLastRecursion: Bool = false, _ onCompletion: @escaping ((Bool) -> ())) {
        if !ensurePushAccess {
            if accessState == .granted {
                onCompletion(true); return
            } else if accessState == .rejected {
                onCompletion(false); return
            }
        } else {
            if accessState == .granted, pushState == .apnsRegistrationSuccessful {
                onCompletion(true); return
            } else if accessState == .rejected || pushState == .apnsRegistrationFailed {
                onCompletion(false); return
            }
        }
        
        if forceLastRecursion {
            onCompletion(false)
            return
        }
        
        if accessState == .unknown {
            refreshAccessStates(registerPushAccess: false) { _ in
                self.ensureAccess(ensurePushAccess: ensurePushAccess) { onCompletion($0) }
            }
            return
        } else if accessState == .notAsked {
            requestAccess(registerPushAccess: false) { _ in
                self.ensureAccess(ensurePushAccess: ensurePushAccess) { onCompletion($0) }
            }
            return
        } else if accessState != .granted {
            print("FATAL: Access state is \"\(accessState)\" although it must be \".granted\" in every case.",
            "Maybe added a new access state case but didn't consider it in the ensureAccess function yet?")
            onCompletion(false); return
        }
        
        if pushState == .unknown {
            registerForRemoteNotifications()
            ensureAccess(ensurePushAccess: ensurePushAccess) { onCompletion($0) }
            return
        } else if pushState == .asked {
            var pushStateCancellable: AnyCancellable? = nil
            pushStateCancellable = publishedPushState.dropFirst().sink { newPushState in
                if newPushState != .asked {
                    self.ensureAccess(ensurePushAccess: ensurePushAccess, forceLastRecursion: true) { onCompletion($0) }
                    pushStateCancellable?.cancel()
                    return
                }
            }
        }
    }
}
