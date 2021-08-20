//
//  NotificationService.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Combine
import UIKit
import UserNotifications

class NotificationService: ObservableObject {
    enum AccessState {
        case unknown
        case granted
        case notAsked
        case rejected
    }
    
    enum PushNotificationState {
        case unknown
        case apnsRegistrationGranted
        case apnsRegistrationFailed
    }
    
    enum APINotificationUploadState {
        case notUploading
        case uploadInProgress
        case uploadCompleted
        case uploadFailed
    }
    
    var token: String? = nil
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
    
    func registeredForRemoteNotifications(rawNewToken: Data) {
        logger.debug("Remote notifications granted with device token.")

        if let appSettingsEntity = appSettings.entity,
           let notificationSettingsEntity = notificationSettings.entity,
           let region = Region(rawValue: appSettingsEntity.regionIdentifier)
        {
            pushNotificationState = .apnsRegistrationGranted
            
            let newToken = rawNewToken.map {
                String(format: "%02.2hhx", $0)
            }.joined()
            self.token = newToken
            
            let isNewToken = notificationSettingsEntity.lastApnsToken != newToken
            
            if isNewToken {
                let tasks = APINotificationInterface(token: newToken)
                    .addAddTokenTask(payload: AddTokenPayload(region: region, tax: appSettingsEntity.pricesWithVAT))
        
                if notificationSettingsEntity.lastApnsToken != nil {
                    // Upload all settings, add here
                }
                
                if let packedTasks = tasks.getPackedTasks(),
                   let request = APIRequestFactory.notificationRequest(packedTasks: packedTasks)
                {
                    performNotificationAPIRequest(request: request)
                        .sink { completion in
                            if case .finished = completion { self.notificationSettings.changeLastApnsToken(to: newToken) }
                        } receiveValue: { _ in }
                        .store(in: &cancellables)
                }
            }
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
}
