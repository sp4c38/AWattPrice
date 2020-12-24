//
//  AppDelegate.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var currentSetting: CurrentSetting? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registration from APNs for push notifications was granted.")
        
        let apnsDeviceTokenString = deviceToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()
        
        if self.currentSetting != nil {
            if currentSetting!.entity != nil {
                if currentSetting!.entity!.lastApnsToken != apnsDeviceTokenString {
                    print("Need to update stored APNs token. Stored token and current APNs token are not identical.")
                    let requestSuccessful = uploadApnsTokenToServer(deviceToken: apnsDeviceTokenString)
                    if requestSuccessful {
                        self.currentSetting!.changeLastApnsToken(newApnsToken: apnsDeviceTokenString)
                    }
                } else {
                    print("No need to update stored APNs token. Stored token and current APNs token are identical.")
                }
            }
        } else {
            print("Settings could not be found. Therefor can't store last APNs token.")
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Registration to APNs for push notifications was NOT granted: \(error.localizedDescription)")
    }
}
