//
//  NotificationService+Requests.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Combine
import Foundation

extension NotificationService {
    /// Try to receive the required notification access permissions and send the notification request.
    func sendNotificationConfiguration(_ notificationConfiguration: NotificationConfiguration, _ notificationSetting: CurrentNotificationSetting) -> AnyPublisher<(data: Data, response: URLResponse), Error>? {
        guard accessState.value == .granted, pushState.value == .apnsRegistrationSuccessful else { return nil }
        
        guard let apiRequest = APIRequestFactory.notificationRequest(notificationConfiguration) else { return nil }
        let request = APIClient().request(to: apiRequest)
        request
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Successfully sent notification task.")
                case .failure(let error):
                    print("Couldn't sent notification tasks: \(error).")
                    notificationSetting.changeForceUpload(to: true)
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
        
        return request
    }
    
    func wantToReceiveAnyNotification(notificationSetting: CurrentNotificationSetting) -> Bool {
        if notificationSetting.entity!.priceDropsBelowValueNotification == true {
            return true
        } else {
            return false
        }
    }
    
    func changeNotificationConfiguration(
        _ notificationConfiguration: NotificationConfiguration, _ notificationSetting: CurrentNotificationSetting, ensurePushAccess: Bool = true, skipWantNotificationCheck: Bool = false,
        uploadStarted: ((AnyPublisher<(data: Data, response: URLResponse), Error>) -> ())? = nil, cantStartUpload: (() -> ())? = nil, noUpload: (() -> ())? = nil
    ) {
        var notificationConfiguration = notificationConfiguration
        
        if skipWantNotificationCheck || wantToReceiveAnyNotification(notificationSetting: notificationSetting) {
            ensureAccess(ensurePushAccess: ensurePushAccess) { access in
                if access, let token = self.token {
                    if notificationConfiguration.token == nil {
                        notificationConfiguration.token = token
                    }
                    
                    if let sendPublisher = self.sendNotificationConfiguration(notificationConfiguration, notificationSetting) {
                        uploadStarted?(sendPublisher)
                    } else {
                        cantStartUpload?()
                    }
                } else {
                    print("Didn't get notification access.")
                    cantStartUpload?()
                }
            }
        } else {
            print("User doesn't want to receive any notifications and thus don't need to upload.")
            noUpload?()
        }
    }
}
