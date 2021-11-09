//
//  NotificationService+AskAccess.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Combine
import UserNotifications

extension NotificationService {
    func refreshAccessStates(onCompletion: ((AccessState) -> ())? = nil) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    print("Notification: Notification access granted.")
                    self.accessState = .granted
                    self.registerForRemoteNotifications()
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
    }
    
    func requestAccess(onCompletion: ((AccessState) -> ())? = nil) {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { authorizationGranted, error in
            if let error = error {
                print("Notification: Notification access failed with error: \(error).")
                return
            }
            self.refreshAccessStates(onCompletion: onCompletion)
        }
    }
    
    func ensureAccess(_ onCompletion: ((Bool) -> ())? = nil) {
        if accessState == .notAsked {
            if let onCompletion = onCompletion {
                requestAccess { newAccess in
                    if newAccess == .granted {
                        if self.pushState == .apnsRegistrationSuccessful { onCompletion(true)
                        } else if self.pushState == .apnsRegistrationFailed { onCompletion(false)
                        } else if self.pushState == .asked {
                            var pushStateCancellable: AnyCancellable? = nil
                            pushStateCancellable = self.$pushState.dropFirst().sink { newPushState in
                                if newPushState != .asked {
                                    if newPushState == .apnsRegistrationSuccessful {
                                        pushStateCancellable?.cancel()
                                        onCompletion(true)
                                    } else {
                                        pushStateCancellable?.cancel()
                                        onCompletion(false)
                                    }
                                }
                            }
                        }
                    } else { onCompletion(false) }
                }
            } else { requestAccess() }
        } else if accessState == .granted, pushState == .apnsRegistrationSuccessful {
            onCompletion?(true)
        } else {
            onCompletion?(false)
        }
    }
}
