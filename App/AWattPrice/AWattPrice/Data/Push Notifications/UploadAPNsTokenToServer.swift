//
//  UploadAPNsTokenToServer.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import Foundation

class UploadPushNotificationConfigRepresentable: Encodable {
    class NotificationConfig: Encodable {
        var priceBelowValueNotification: Bool
        var priceBelowValue: Double
        
        init(_ priceBelowValueNotification: Bool, _ priceBelowValue: Double) {
            self.priceBelowValueNotification = priceBelowValueNotification
            self.priceBelowValue = priceBelowValue
        }
    }
    
    let apnsDeviceToken: String
    let regionIdentifier: Int
    let notificationConfig: NotificationConfig
    init(_ apnsDeviceTokenString: String, regionIdentifier: Int, _ notifiSetting: NotificationSetting) {
        self.apnsDeviceToken = apnsDeviceTokenString
        self.regionIdentifier = regionIdentifier
        self.notificationConfig = NotificationConfig(notifiSetting.priceDropsBelowValueNotification, notifiSetting.priceBelowValue)
    }
}

func uploadPushNotificationSettings(configuration: UploadPushNotificationConfigRepresentable) -> Bool {
    struct ReturnCode: Decodable {
        var tokenWasPassedSuccessfully: Bool
    }
    
    struct SendData: Encodable {
        var apnsDeviceToken: String
    }
    
    let sendURL = GlobalAppSettings.rootURLString + "/data/apns/send_token"
    var request = URLRequest(url: URL(string: sendURL)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)

    let jsonEncoder = JSONEncoder()
    let encodedJSON: Data?
    do {
        encodedJSON = try jsonEncoder.encode(configuration)
    } catch {
        encodedJSON = nil
    }
    guard let requestBody = encodedJSON else { return false }

    request.httpMethod = "POST"
    request.httpBody = requestBody

    var returnCode: ReturnCode? = nil
    
    let dispatchSemaphore = DispatchSemaphore(value: 0)
    let _ = URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            let jsonDecoder = JSONDecoder()
            do {
                let decodedReturn = try jsonDecoder.decode(ReturnCode.self, from: data) // ReturnCode.self: metatype

                returnCode = decodedReturn
            } catch {
                print("Couldn't decode the data returned from the provider server after trying to pass the notification token to the provider server. Error: \(error).")
            }
        }

        if let error = error {
            print("Error sending APNs token to server: \(error).")
        }
        dispatchSemaphore.signal()
    }
    .resume()

    dispatchSemaphore.wait()
    
    if returnCode == nil {
        return false
    } else if returnCode!.tokenWasPassedSuccessfully == true {
        print("APNs token was successfully passed on to the Apps provider server.")
        return true
    } else if returnCode!.tokenWasPassedSuccessfully == false {
        print("APNs couldn't be passed on to the Apps provider server.")
        return false
    } else {
        return false
    }
}

func tryNotificationUploadAfterFailed(_ regionIdentifier: Int, _ crtNotifiSetting: CurrentNotificationSetting, _ networkManager: NetworkManager) {
    print("Detected changes to current notification configuration which could previously NOT be uploaded successful. Trying to upload again in background when network connection is satisfied and a APNs token was set.")
    // If there were changes to the notification preferences but they couldn't be uploaded (e.g. no internet connection or other process currently uploading to server) than a background queue is initiated to take care of uploading these notification preferences as soon as no proces is currently sending to server and there is a internet connection.
    
    let resolveNotificationErrorUploadingQueue = DispatchQueue(label: "NotificationErrorUploadingQueue", qos: .background)
    resolveNotificationErrorUploadingQueue.async {
        crtNotifiSetting.currentlySendingToServer.lock()
        while ((networkManager.networkStatus == .unsatisfied) || (crtNotifiSetting.entity!.lastApnsToken == nil)) {
            // Only run further if the network connection is satisfied
            sleep(1)
        }
        let notificationConfig = UploadPushNotificationConfigRepresentable(
            crtNotifiSetting.entity!.lastApnsToken!,
            regionIdentifier: regionIdentifier,
            crtNotifiSetting.entity!)
        let requestSuccessful = uploadPushNotificationSettings(configuration: notificationConfig)
        if requestSuccessful {
            print("Could successfuly upload notification configuration after previously an upload failed.")
            crtNotifiSetting.entity!.changesButErrorUploading = false
        } else {
            print("Could still NOT upload notification configuration after previously also an upload failed.")
        }
        crtNotifiSetting.currentlySendingToServer.unlock()
    }
}
