//
//  UploadAPNsTokenToServer.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import Foundation

class UploadPushNotificationConfigRepresentable: Encodable {
    class NotificationConfig: Encodable {
        class PriceBelowValueNotification: Encodable {
            var active: Bool
            var belowValue: Int

            init(active: Bool, belowValue: Int) {
                self.active = active
                self.belowValue = belowValue
            }
        }

        var priceBelowValueNotification: PriceBelowValueNotification

        init(active: Bool, priceBelowValue: Int) {
            priceBelowValueNotification = PriceBelowValueNotification(
                active: active,
                belowValue: priceBelowValue
            )
        }
    }

    let apnsDeviceToken: String
    let regionIdentifier: Int
    let vatSelection: Int
    let notificationConfig: NotificationConfig

    init(_ apnsDeviceTokenString: String, _ regionIdentifier: Int, _ vatSelection: Int, _ notifiSetting: NotificationSetting) {
        apnsDeviceToken = apnsDeviceTokenString
        self.regionIdentifier = regionIdentifier
        self.vatSelection = vatSelection
        notificationConfig = NotificationConfig(active: notifiSetting.priceDropsBelowValueNotification, priceBelowValue: notifiSetting.priceBelowValue)
    }

    func checkUserWantsNotifications() -> Bool {
        // Check if the user would like to receive notification at all
        if notificationConfig.priceBelowValueNotification.active == true {
            return true
        }

        return false
    }
}

//extension BackendCommunicator {
//    func uploadPushNotificationSettings(configuration: UploadPushNotificationConfigRepresentable) -> Bool {
//        struct ReturnCode: Decodable {
//            var tokenWasPassedSuccessfully: Bool
//        }
//
//        struct SendData: Encodable {
//            var apnsDeviceToken: String
//        }
//
//        let sendURL = AppContext.shared.config.apiURL.appendingPathComponent("/data/apns/send_token")
//        var request = URLRequest(url: sendURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
//
//        let jsonEncoder = JSONEncoder()
//        let encodedJSON: Data?
//        do {
//            encodedJSON = try jsonEncoder.encode(configuration)
//        } catch {
//            encodedJSON = nil
//        }
//        guard let requestBody = encodedJSON else { return false }
//
//        request.httpMethod = "POST"
//        request.httpBody = requestBody
//
//        var returnCode: ReturnCode?
//
//        let dispatchSemaphore = DispatchSemaphore(value: 0)
//        URLSession.shared.dataTask(with: request) { data, _, error in
//            if let data = data {
//                let jsonDecoder = JSONDecoder()
//                do {
//                    let decodedReturn = try jsonDecoder.decode(ReturnCode.self, from: data) // ReturnCode.self: metatype
//
//                    returnCode = decodedReturn
//                } catch {
//                    logger.error("""
//                        Couldn't decode returned data from the provider server after trying to pass the notification
//                        token to it: \(error.localizedDescription).
//                    """)
//                }
//            }
//
//            if let error = error {
//                logger.notice("Error sending APNs token to server (e.g.: server maybe down?): \(error.localizedDescription).")
//            }
//            dispatchSemaphore.signal()
//        }
//        .resume()
//
//        dispatchSemaphore.wait()
//
//        DispatchQueue.main.async {
//            if returnCode == nil {
//                self.notificationUploadError = true
//            } else if returnCode!.tokenWasPassedSuccessfully == true {
//                logger.debug("APNs token was successfully passed on to the provider server.")
//                self.notificationUploadError = false
//            } else if returnCode!.tokenWasPassedSuccessfully == false {
//                logger.error("Provider-side received notification data couldn't be validated successfully (server-side).")
//                self.notificationUploadError = true
//            } else {
//                self.notificationUploadError = true
//            }
//        }
//
//        return (notificationUploadError == true ? false : true) // Need to switch because returns as request successful
//    }
//
//    func tryNotificationUploadAfterFailed(_ regionIdentifier: Int, _ vatSelection: Int, _ crtNotifiSetting: CurrentNotificationSetting, _ networkManager: NetworkManager) {
//        logger.info("""
//            Detected changes to current notification configuration which could previously NOT be uploaded successful.
//            Trying to upload again in background when network connection is satisfied and a APNs token was set.
//        """)
//        // If there were changes to the notification preferences but they couldn't be uploaded
//        // (e.g. no internet connection or other process currently uploading to server) than a background
//        // queue is initiated to take care of uploading these notification preferences as soon as
//        // no proces is currently sending to server and there is a internet connection.
//
//        let resolveNotificationErrorUploadingQueue = DispatchQueue(
//            label: "NotificationErrorUploadingQueue",
//            qos: .background
//        )
//        resolveNotificationErrorUploadingQueue.async {
//            crtNotifiSetting.currentlySendingToServer.lock()
//            while (networkManager.networkStatus == .unsatisfied) || (crtNotifiSetting.entity!.lastApnsToken == nil) {
//                // Only run further if the network connection is satisfied
//                sleep(1)
//            }
//            let notificationConfig = UploadPushNotificationConfigRepresentable(
//                crtNotifiSetting.entity!.lastApnsToken!,
//                regionIdentifier,
//                vatSelection,
//                crtNotifiSetting.entity!
//            )
//            let requestSuccessful = self.uploadPushNotificationSettings(configuration: notificationConfig)
//            if requestSuccessful {
//                logger.debug("Could successfuly upload notification configuration after previously an upload failed.")
//                crtNotifiSetting.changeChangesButErrorUploading(to: false)
//            } else {
//                logger.notice("Could still NOT upload notification configuration after previously also an upload failed.")
//            }
//            crtNotifiSetting.currentlySendingToServer.unlock()
//        }
//    }
//}
