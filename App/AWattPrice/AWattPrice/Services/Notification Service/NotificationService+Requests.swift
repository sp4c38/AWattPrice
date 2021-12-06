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
    func sendNotificationConfiguration(_ notificationConfiguration: NotificationConfiguration, _ notificationSetting: CurrentNotificationSetting) -> AnyPublisher<Never, Error>? {
        guard accessState == .granted, pushState == .apnsRegistrationSuccessful else { return nil }
        
        guard let apiRequest = APIRequestFactory.notificationRequest(notificationConfiguration) else { return nil }
        let request = APIClient().request(to: apiRequest)
        
        request
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Successfully sent notification task.")
                    self.stateLastUpload = .success
                case .failure(let error):
                    print("Couldn't sent notification tasks: \(error).")
                    self.stateLastUpload = .failure(error: error)
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
        uploadFinished: (() -> ())? = nil, uploadError: (() -> ())? = nil, noUpload: (() -> ())? = nil
    ) {
        var notificationConfiguration = notificationConfiguration
        
        if skipWantNotificationCheck || wantToReceiveAnyNotification(notificationSetting: notificationSetting) {
            ensureAccess(ensurePushAccess: ensurePushAccess) { access in
                if access, let token = self.token {
                    if notificationConfiguration.token == nil {
                        notificationConfiguration.token = token
                    }
                    
                    if let sendPublisher = self.sendNotificationConfiguration(notificationConfiguration, notificationSetting) {
                        sendPublisher.sink(receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                uploadFinished?()
                            case .failure(_):
                                uploadError?()
                            }
                        }, receiveValue: {_ in }).store(in: &self.cancellables)
                    }
                } else {
                    print("Didn't get notification access.")
                    noUpload?()
                }
            }
        } else {
            print("User doesn't want to receive any notifications and thus don't need to upload.")
            noUpload?()
        }
    }
}
