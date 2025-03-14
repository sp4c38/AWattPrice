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
}
