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
        guard isUploading.tryLock() == false else { return nil } // Must be already locked, otherwise fail.
        let response = APIClient().request(to: request)å
        
        response
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isUploading.releaseLock()
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
    func runNotificationRequest(interface: APINotificationInterface, appSetting: CurrentSetting, notificationSetting: CurrentNotificationSetting, onSuccess: (() -> ())? = nil) {
        guard accessState == .granted, pushState == .apnsRegistrationSuccessful, isUploading.tryLock() == true,
              let extendedInterface = extendNotificationInterface(interface, appSetting: appSetting)
        else { return }
        let packedTasks = extendedInterface.getPackedTasks()
        
        guard let apiRequest = APIRequestFactory.notificationRequest(packedTasks: packedTasks) else { return }
        if let request = sendNotificationRequest(request: apiRequest) {
            request
                .sink { completion in
                    if case .finished = completion {
                        extendedInterface.copyToSettings(appSetting: appSetting, notificationSetting: notificationSetting)
                        onSuccess?()
                    }
                } receiveValue: { _ in }
                .store(in: &cancellables)
        }
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
