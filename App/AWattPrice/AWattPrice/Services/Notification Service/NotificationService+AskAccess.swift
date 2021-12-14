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
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                print("Notification: Notification access granted.")
                self.accessState.value = .granted
                if registerPushAccess {
                    self.registerForRemoteNotifications()
                }
            case .notDetermined:
                print("Notification: Notification access wasn't asked for yet.")
                self.accessState.value = .notAsked
            default:
                print("Notification: Notification access not allowed: \(settings.authorizationStatus).")
                self.accessState.value = .rejected
            }
            
            onCompletion?(self.accessState.value)
        }
    }
    
    func requestAccess(registerPushAccess: Bool = true, onCompletion: ((AccessState) -> ())? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
            if let error = error {
                print("Notification: Notification access failed with error: \(error).")
                return
            }
            self.refreshAccessStates(registerPushAccess: registerPushAccess, onCompletion: onCompletion)
        }
    }
    
    func ensureAccess(ensurePushAccess: Bool = true, forceLastRecursion: Bool = false, _ onCompletion: @escaping ((Bool) -> ())) {
        if !ensurePushAccess {
            if accessState.value == .granted {
                onCompletion(true); return
            } else if accessState.value == .rejected {
                onCompletion(false); return
            }
        } else {
            if accessState.value == .granted, pushState.value == .apnsRegistrationSuccessful {
                onCompletion(true); return
            } else if accessState.value == .rejected || pushState.value == .apnsRegistrationFailed {
                onCompletion(false); return
            }
        }
        
        if forceLastRecursion {
            onCompletion(false)
            return
        }
        
        if accessState.value == .unknown {
            refreshAccessStates(registerPushAccess: false) { _ in
                self.ensureAccess(ensurePushAccess: ensurePushAccess) { onCompletion($0) }
            }
            return
        } else if accessState.value == .notAsked {
            requestAccess(registerPushAccess: false) { _ in
                self.ensureAccess(ensurePushAccess: ensurePushAccess) { onCompletion($0) }
            }
            return
        } else if accessState.value != .granted {
            print("FATAL: Access state is \"\(accessState)\" although it must be \".granted\" in every case.",
            "Maybe added a new access state case but didn't consider it in the ensureAccess function yet?")
            onCompletion(false); return
        }
        
        if pushState.value == .unknown {
            registerForRemoteNotifications()
            ensureAccess(ensurePushAccess: ensurePushAccess) { onCompletion($0) }
            return
        } else if pushState.value == .asked {
            var pushStateCancellable: AnyCancellable? = nil
            pushStateCancellable = pushState.dropFirst().sink { newPushState in
                if newPushState != .asked {
                    self.ensureAccess(ensurePushAccess: ensurePushAccess, forceLastRecursion: true) { onCompletion($0) }
                    pushStateCancellable?.cancel()
                    return
                }
            }
        }
    }
}
