//
//  UploadAPNsTokenToServer.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import Foundation

func uploadApnsTokenToServer(deviceToken: Data) {
    struct ReturnCode: Decodable {
        var tokenWasPassedSuccessfully: Bool
    }
    
    struct SendData: Encodable {
        var apnsDeviceToken: String
    }
    
    let sendURL = GlobalAppSettings.rootURLString + "/data/apns/send_token"
    var request = URLRequest(url: URL(string: sendURL)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
    
    let apnsDeviceTokenString = deviceToken.map {
        String(format: "%02.2hhx", $0)
    }.joined()
    let sendData = SendData(apnsDeviceToken: apnsDeviceTokenString)
    
    let jsonEncoder = JSONEncoder()
    let encodedJSON: Data?
    do {
        encodedJSON = try jsonEncoder.encode(sendData)
    } catch {
        encodedJSON = nil
    }
    guard let requestBody = encodedJSON else { return }
    
    request.httpMethod = "POST"
    request.httpBody = requestBody
    
    let _ = URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            let jsonDecoder = JSONDecoder()
            do {
                let decodedReturn = try jsonDecoder.decode(ReturnCode.self, from: data) // ReturnCode.self: metatype
                if decodedReturn.tokenWasPassedSuccessfully == true {
                    print("APNs token was successfully passed on to the Apps provider server.")
                } else {
                    print("APNs couldn't be passed on to the Apps provider server.")
                }
            } catch {
                print("Couldn't decode the data returned from the provider server after trying to pass the notification token to the provider server. Error: \(error).")
            }
        }
        
        if let error = error {
            print("Error sending APNs token to server: \(error).")
        }
    }.resume()
}
