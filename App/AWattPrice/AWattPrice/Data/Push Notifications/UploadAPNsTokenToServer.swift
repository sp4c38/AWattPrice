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
    
    var request = URLRequest(url: URL(string: "https://www.space8.me/testing")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
    request.httpMethod = "POST"
    request.httpBody = deviceToken.base64EncodedString().data(using: .utf8)
    
    let _ = URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            let jsonDecoder = JSONDecoder()
            do {
                let decodedReturn = try jsonDecoder.decode(ReturnCode.self, from: data) // ReturnCode.self: metatype
                if decodedReturn.tokenWasPassedSuccessfully == true {
                    print("Token was successfully passed on to the provider server.")
                }
            } catch {
                print("Couldn't decode the data returned from the provider server after trying to pass the notification token to the provider server. Error: \(error).")
            }
        }
    }.resume()
}
