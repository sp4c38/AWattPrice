//
//  UploadAPNsTokenToServer.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import Foundation

class UploadPushNotificationConfigRepresentable: Encodable {
    let apnsDeviceToken: String
    let notificationConfig: [String: Bool]
    init(_ apnsDeviceTokenString: String, _ newPricesAvailableNotification: Bool) {
        self.apnsDeviceToken = apnsDeviceTokenString
        self.notificationConfig = ["newPriceAvailable": newPricesAvailableNotification]
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
