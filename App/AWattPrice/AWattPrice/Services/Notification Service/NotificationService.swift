//
//  NotificationService.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Combine
import Resolver
import UserNotifications

extension NotificationService {
    enum AccessState {
        case unknown
        case granted
        case notAsked
        case rejected
    }
    
    enum PushNotificationState {
        case unknown
        case asked
        case apnsRegistrationSuccessful
        case apnsRegistrationFailed
    }
    
    enum APINotificationRequestState {
        case noRequest
        case requestInProgress
        case requestCompleted
        case requestFailed
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
}

class NotificationService: ObservableObject {
    var tokenContainer: TokenContainer? = nil
    @Injected var appSettings: CurrentSetting
    @Injected var notificationSettings: CurrentNotificationSetting
    
    @Published var accessState: AccessState = .unknown
    @Published var pushNotificationState: PushNotificationState = .unknown
    @Published var apiNotificationRequestState: APINotificationRequestState = .noRequest
    
    let notificationCenter = UNUserNotificationCenter.current()
    internal var notificationRequestCancellable: AnyCancellable? = nil
    internal var cancellables = [AnyCancellable]()
}
