//
//  NotificationService+Requests.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.08.21.
//

import Combine
import Foundation

extension NotificationService {
    private func sendNotificationRequest(request: PlainAPIRequest) -> AnyPublisher<Never, Error>? {
        guard makingNotificationRequest.try() == true else { return nil }
        let response = APIClient().request(to: request)
        
        response
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.makingNotificationRequest.unlock()
                switch completion {
                case .finished:
                    print("Successfully sent notification tasks.")
                case .failure(let error):
                    print("Couldn't sent notification tasks: \(error).")
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
        
        return response
    }
    
    internal func performNotificationRequest(_ apiRequest: PlainAPIRequest) {
        if pushNotificationState == .apnsRegistrationSuccessful {
            print("Notification: Sending request as all required permissions are granted.")
            sendNotificationRequest(request: apiRequest)
        } else if pushNotificationState == .apnsRegistrationFailed {
            print("Notification: Can't send notification request as apns registration failed.")
            return
        }
    }
    
    /// Try to receive the required notification access permissions and send the notification request.
    func runNotificationRequest(apiRequest: PlainAPIRequest) {
        if self.accessState == .notAsked {
            requestAccess { self.performNotificationRequest(apiRequest) }
        } else {
            performNotificationRequest(apiRequest)
        }
    }
    
    func getBaseNotificationInterface(appSetting: CurrentSetting) -> APINotificationInterface? {
        guard let tokenContainer = self.tokenContainer,
              let appSettingEntity = appSetting.entity
        else { return nil }
        let interface = APINotificationInterface(token: tokenContainer.token)
        
        if tokenContainer.nextUploadState == .addTokenTask, let region = Region(rawValue: appSettingEntity.regionIdentifier) {
            interface.addAddTokenTask(AddTokenPayload(region: region, tax: appSettingEntity.pricesWithVAT))
        } else if tokenContainer.nextUploadState == .uploadAllNotificationConfig {
            // IMPLEMENT: UPLOAD ALL
        }
        
        return interface
    }
}
