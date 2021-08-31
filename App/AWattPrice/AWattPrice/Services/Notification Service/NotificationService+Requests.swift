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
    
    /// Try to receive the required notification access permissions and send the notification request.
    func runNotificationRequest(interface: APINotificationInterface, appSetting: CurrentSetting) {
        guard accessState == .granted, pushState == .apnsRegistrationSuccessful,
              let extendedInterface = extendNotificationInterface(interface, appSetting: appSetting)
        else { return }
        let packedTasks = extendedInterface.getPackedTasks()
        guard let apiRequest = APIRequestFactory.notificationRequest(packedTasks: packedTasks) else { return }
        
        sendNotificationRequest(request: apiRequest)
    }
    
    /// Extends the notification interface by adding missing tasks which are required to be sent with this notification request.
    func extendNotificationInterface(_ interface: APINotificationInterface, appSetting: CurrentSetting) -> APINotificationInterface? {
        guard let tokenContainer = self.tokenContainer,
              let appSettingEntity = appSetting.entity
        else { return nil }
        
        if tokenContainer.nextUploadState == .addTokenTask, let region = Region(rawValue: appSettingEntity.regionIdentifier) {
            interface.addAddTokenTask(AddTokenPayload(region: region, tax: appSettingEntity.pricesWithVAT), overwrite: false)
        } else if tokenContainer.nextUploadState == .uploadAllNotificationConfig {
            // IMPLEMENT: UPLOAD ALL
        }
        
        return interface
    }
}
