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

class NotificationService {
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
    
    var accessState: CurrentValueSubject<AccessState, Never> = .init(.unknown)
    var pushState: CurrentValueSubject<PushState, Never> = .init(.unknown)
    
    internal var cancellables = [AnyCancellable]()
}
