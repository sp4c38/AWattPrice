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
        case uploadInProgress
        case uploadCompleted
        case uploadFailed
        case apnsRegistrationFailed
    }
    
    @Published var accessState: AccessState = .unknown
    @Published var pushNotificationState: PushNotificationState = .unknown
    
    var token: String? = nil
    
    let notificationCenter = UNUserNotificationCenter.current()
    let appSettings: CurrentSetting
    let notificationSettings: CurrentNotificationSetting
    var cancellables = [AnyCancellable]()
    
    init(appSettings: CurrentSetting, notificationSettings: CurrentNotificationSetting) {
        self.appSettings = appSettings
        self.notificationSettings = notificationSettings
        refreshAccessState()
    }
    
    func sendNotificationAPIRequest(notificationRequest: PlainAPIRequest) {
        let apiClient = APIClient()
        apiClient.request(to: notificationRequest)
            .sink { completion in
                switch completion {
                case .finished:
                    self.pushNotificationState = .uploadCompleted
                case .failure(let error):
                    print("Couldn't send notification tasks: \(error).")
                    self.pushNotificationState = .uploadFailed
                }
            } receiveValue: { _ in
            }
            .store(in: &cancellables)
    }
    
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func registeredForRemoteNotifications(rawToken: Data) {
        logger.debug("Remote notifications granted with device token.")

        let token = rawToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()
        self.token = token

        if let appSettingsEntity = appSettings.entity,
           let notificationSettingEntity = notificationSettings.entity,
           let region = Region(rawValue: appSettingsEntity.regionIdentifier)
        {
            let interface = APINotificationInterface(token: token)
            interface.addAddTokenTask(payload: AddTokenPayload(region: region, tax: appSettingsEntity.pricesWithVAT))
            if let packedTasks = interface.getPackedTasks(),
               let notificationRequest = APIRequestFactory.notificationRequest(tasks: packedTasks)
            {
                sendNotificationAPIRequest(notificationRequest: notificationRequest)
            }
        }
        
//            crtNotifiSetting!.currentlySendingToServer.lock()


//                if notificationConfigRepresentable.checkUserWantsNotifications() == true ||
//                    crtNotifiSetting!.entity!.changesButErrorUploading == true
//                {
//                    if crtNotifiSetting!.entity!.lastApnsToken != apnsDeviceTokenString ||
//                        crtNotifiSetting!.entity!.changesButErrorUploading == true
//                    {
//                        DispatchQueue.global(qos: .background).async {
//                            logger.info("""
//                                Need to update stored APNs configuration. Stored APNs token and current
//                                APNs token mismatch OR previously notification configuration couldn't be
//                                uploaded because of some issue.
//                            """)
//                            let group = DispatchGroup()
//                            group.enter()
//                            DispatchQueue.main.async {
//                                self.crtNotifiSetting!.changeChangesButErrorUploading(to: false)
//                                group.leave()
//                            }
//                            group.wait()
//                            let requestSuccessful = self.backendComm!.uploadPushNotificationSettings(
//                                configuration: notificationConfigRepresentable
//                            )
//                            if !requestSuccessful {
//                                DispatchQueue.main.async {
//                                    self.crtNotifiSetting!.changeChangesButErrorUploading(to: true)
//                                }
//                            }
//                        }
//                    } else {
//                        logger.debug("""
//                            No need to update stored APNs configuration. Stored token matches current APNs
//                            token and no errors previously occurred when uploading changes.
//                        """)
//                    }
//                }
//                crtNotifiSetting!.changeLastApnsToken(to: apnsDeviceTokenString)
//            }
//            crtNotifiSetting!.currentlySendingToServer.unlock()
//        } else {
//            logger.error("Settings could not be found. Therefor can't store last APNs token.")
//        }
    }
    
    func failedRegisteredForRemoteNotifications(error: Error) {
        print("Push notification registration not granted: \(error).")
        pushNotificationState = .apnsRegistrationFailed
    }
    
    func refreshAccessState() {
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.accessState = .granted
                self.registerForRemoteNotifications()
            case .notDetermined:
                self.accessState = .notAsked
            default:
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
            if authorizationGranted {
                self.accessState = .granted
                self.registerForRemoteNotifications()
            } else {
                self.accessState = .rejected
            }
        }
    }
}
