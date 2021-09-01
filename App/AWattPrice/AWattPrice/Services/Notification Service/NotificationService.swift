//
//  NotificationService.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Combine
import Resolver
import SwiftUI
import UserNotifications

class PublishedNSLock: ObservableObject {
    private let lock = NSLock()
    @Published var isLocked = false
    
    func acquireLock() {
        self.lock.lock()
        if isLocked != true { isLocked = true }
    }
    
    func releaseLock() {
        self.lock.unlock()
        if isLocked != false { isLocked = false }
    }
    
    func tryLock() -> Bool {
        let trySuccessful = self.lock.try()
        let currentIsLocked = trySuccessful
        if isLocked != currentIsLocked { isLocked = currentIsLocked }
        return trySuccessful
    }
}

class NotificationService: ObservableObject {
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

    var tokenContainer: TokenContainer? = nil
    
    @Published var accessState: AccessState = .unknown
    @Published var pushState: PushState = .unknown
    @ObservedObject var isUploading = PublishedNSLock()
    
    internal let notificationCenter = UNUserNotificationCenter.current()
    internal var notificationRequestCancellable: AnyCancellable? = nil
    
    internal var cancellables = [AnyCancellable]()
    internal var ensureAccessPushStateCancellable: AnyCancellable? = nil
}
