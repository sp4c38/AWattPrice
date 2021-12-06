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
    
    enum StateLastUpload {
        case none
        case success
        case failure(error: Error)
    }
    
    var token: String? = nil
    
    var publishedAccessState: CurrentValueSubject<AccessState, Never>
    var publishedPushState: CurrentValueSubject<PushState, Never>
    
    var accessState: AccessState {
        didSet { publishedAccessState.send(accessState) }
    }
    var pushState: PushState {
        didSet { publishedPushState.send(pushState) }
    }
    
    @Published var stateLastUpload: StateLastUpload = .none
    
    internal let notificationCenter = UNUserNotificationCenter.current()
    
    internal var cancellables = [AnyCancellable]()
    
    init() {
        publishedAccessState = .init(.unknown)
        accessState = .unknown
        
        publishedPushState = .init(.unknown)
        pushState = .unknown
    }
}
