//
//  NotificationService.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Combine
import Resolver
import UserNotifications

class NotificationService: ObservableObject {
    enum AccessState {
        case unknown
        case notAsked
        case granted
        case rejected
    }
    
    enum PushNotificationState {
        case unknown
        case asked
        case apnsRegistrationSuccessful
        case apnsRegistrationFailed
    }
    
    struct TokenContainer {
        /// Stores what to do when making the next notification request.
        enum NextUploadState {
            case doNothing
            case addTokenTask
            case uploadAllNotificationConfig
        }
        
        let token: String
        var nextUploadState: NextUploadState
    }
    
    var tokenContainer: TokenContainer? = nil
    
    let makingNotificationRequest = NSLock()
    @Published var accessState: AccessState = .unknown
    @Published var pushNotificationState: PushNotificationState = .unknown
    
    internal let notificationCenter = UNUserNotificationCenter.current()
    internal var notificationRequestCancellable: AnyCancellable? = nil
    internal var cancellables = [AnyCancellable]()
}
