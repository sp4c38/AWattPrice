//
//  NotificationService+Requests.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Combine
import Foundation

extension NotificationService {
    func wantToReceiveAnyNotification(notificationSettingEntity: NotificationSetting) -> Bool {
        if notificationSettingEntity.priceDropsBelowValueNotification == true {
            return true
        } else {
            return false
        }
    }
    
    func getBaseNotificationInterface() -> APINotificationInterface? {
        guard let tokenContainer = self.tokenContainer else { return nil }
        let interface = APINotificationInterface(token: tokenContainer.token)
        
        if tokenContainer.nextUploadState == .addTokenTask,
           let appSettingEntity = appSettings.entity,
           let region = Region(rawValue: appSettingEntity.regionIdentifier)
        {
            let payload = AddTokenPayload(region: region, tax: appSettingEntity.pricesWithVAT)
            interface.addAddTokenTask(payload: payload)
        } else if tokenContainer.nextUploadState == .uploadAllNotificationConfig {
            // IMPLEMENT: UPLOAD ALL
        }
        
        return interface
    }
    
    private func sendNotificationRequest(request: PlainAPIRequest, setRequestInProgressFlag: Bool = true) -> AnyPublisher<Never, Error> {
        let apiClient = APIClient()
        let response = apiClient.request(to: request)
        
        response
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Successfully sent notification tasks.")
                    self.apiNotificationRequestState = .requestCompleted
                case .failure(let error):
                    print("Couldn't sent notification tasks: \(error).")
                    self.apiNotificationRequestState = .requestFailed
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
        
        return response
    }
    
    /// Try to receive the required notification access permissions and send the notification request.
    func runNotificationRequest(apiRequest: PlainAPIRequest, onRequestSend: @escaping (AnyPublisher<Never, Error>) -> ()) {
        apiNotificationRequestState = .requestInProgress
        let performAfterAccessAsked = {
            if self.accessState == .granted {
                self.notificationRequestCancellable = self.$pushNotificationState
                    .sink { pushNotificationState in
                        if pushNotificationState == .apnsRegistrationSuccessful {
                            print("Notification: Sending request as all required permissions are granted.")
                            let request = self.sendNotificationRequest(request: apiRequest)
                            onRequestSend(request)
                        } else if pushNotificationState == .apnsRegistrationFailed {
                            print("Notification: Can't send notification request as apns registration failed.")
                            self.apiNotificationRequestState = .requestFailed
                        }
                        if pushNotificationState != .asked {
                            print("Notification: Push notification state was answered, cancelling notification request.")
                            self.notificationRequestCancellable?.cancel()
                        }
                    }
            }
        }
        
        if accessState == .notAsked {
            self.requestAccess { performAfterAccessAsked() }
        } else {
            performAfterAccessAsked()
        }
    }
}
