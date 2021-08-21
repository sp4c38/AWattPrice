//
//  NotificationService.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Combine
import UIKit
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
        case apnsRegistrationSuccessful
        case apnsRegistrationFailed
    }
    
    enum APINotificationUploadState {
        case notUploading
        case uploadInProgress
        case uploadCompleted
        case uploadFailed
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
    let appSettings: CurrentSetting
    let notificationSettings: CurrentNotificationSetting
    
    @Published var accessState: AccessState = .unknown
    @Published var pushNotificationState: PushNotificationState = .unknown
    @Published var apiNotificationUploadState: APINotificationUploadState = .notUploading
    
    let notificationCenter = UNUserNotificationCenter.current()
    private var cancellables = [AnyCancellable]()
    
    init(appSettings: CurrentSetting, notificationSettings: CurrentNotificationSetting) {
        self.appSettings = appSettings
        self.notificationSettings = notificationSettings
    }
    
    func performNotificationAPIRequest(request: PlainAPIRequest) -> AnyPublisher<Never, Error> {
        self.apiNotificationUploadState = .uploadInProgress
        let apiClient = APIClient()
        let response = apiClient.request(to: request)
        
        response
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Successfully sent notification tasks.")
                    self.apiNotificationUploadState = .uploadCompleted
                case .failure(let error):
                    print("Couldn't sent notification tasks: \(error).")
                    self.apiNotificationUploadState = .uploadFailed
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
        
        return response
    }
    
    func registeredForRemoteNotifications(rawCurrentToken: Data) {
        logger.debug("Remote notifications granted with device token.")

        if let appSettingsEntity = appSettings.entity,
           let notificationSettingsEntity = notificationSettings.entity,
           let region = Region(rawValue: appSettingsEntity.regionIdentifier)
        {
            let currentToken = rawCurrentToken.map {
                String(format: "%02.2hhx", $0)
            }.joined()
            
            let isNewToken = notificationSettingsEntity.lastApnsToken != currentToken
            
            if !isNewToken {
                print("Notification: Token isn't new, won't upload.")
                tokenContainer = TokenContainer(token: currentToken, nextUploadState: .doNothing)
            } else if isNewToken, notificationSettingsEntity.lastApnsToken == nil {
                print("Notification: New token and no old token, will parse new token on next notification request.")
                tokenContainer = TokenContainer(token: currentToken, nextUploadState: .addTokenTask)
            } else if isNewToken, notificationSettingsEntity.lastApnsToken != nil {
                if wantToReceiveAnyNotification(notificationSettingEntity: notificationSettingsEntity) {
                    print("Notification: New token, old token exists and want to receive at least one notification, uploading all config now.")
                    tokenContainer = TokenContainer(token: currentToken, nextUploadState: .doNothing)
                    // UPLOAD EVERYTHING HERE
                } else {
                    print("Notification: New token, old token exists but don't want to receive any notification, uploading all config on next notification request.")
                    tokenContainer = TokenContainer(token: currentToken, nextUploadState: .uploadAllNotificationConfig)
                }
            }
            
            pushNotificationState = .apnsRegistrationSuccessful
        }
    }
    
    func failedRegisteredForRemoteNotifications(error: Error) {
        print("Push notification registration not granted: \(error).")
        pushNotificationState = .apnsRegistrationFailed
    }
    
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func refreshAccessStates() {
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                print("Notification access granted.")
                self.accessState = .granted
                self.registerForRemoteNotifications()
            case .notDetermined:
                print("Notification access wasn't asked for yet.")
                self.accessState = .notAsked
            default:
                print("Notification access not allowed: \(settings.authorizationStatus).")
                self.accessState = .rejected
            }
        }
    }
    
    func requestAccess() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { authorizationGranted, error in
            if let error = error {
                print("Notification access failed with error: \(error).")
                return
            }
            self.refreshAccessStates()
        }
    }
    
    func wantToReceiveAnyNotification(notificationSettingEntity: NotificationSetting) -> Bool {
        if notificationSettingEntity.priceDropsBelowValueNotification == true {
            return true
        } else {
            return false
        }
    }
}
