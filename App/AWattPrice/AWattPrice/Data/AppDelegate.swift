//
//  AppDelegate.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registration to APNs for push notifications was successful.")
        uploadApnsTokenToServer(deviceToken: deviceToken)
    }
}
