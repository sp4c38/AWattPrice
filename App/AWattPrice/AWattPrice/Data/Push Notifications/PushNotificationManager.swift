//
//  PushNotificationManager.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import UIKit
import UserNotifications

func managePushNotificationsOnAppStart() {
    DispatchQueue.global(qos: .background).async {
        let notificationAccess = checkNotificationAccess()
        if notificationAccess == true {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else {
        }
    }
}

func checkNotificationAccess() -> Bool {
    var returnResponse: Bool = false
    
    let dispatchSemaphore = DispatchSemaphore(value: 0)
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { successful, error in
        if successful == true && error == nil {
            print("Notification center access was granted.")
            returnResponse = true
        } else if successful == false && error == nil {
            print("Notification center acces was rejected.")
            returnResponse = false
        } else if error != nil {
            print("Notification center acces failed with error: \(error?.localizedDescription ?? "[Couldn't unpack error optional as localized description]").")
            returnResponse = false
        }

        dispatchSemaphore.signal()
    }
    dispatchSemaphore.wait()
    
    return returnResponse
}

func notificationConfigChanged(regionIdentifier: Int, vatSelection: Int, _ crtNotifiSetting: CurrentNotificationSetting) {
    crtNotifiSetting.currentlySendingToServer.lock()
    print("Notification configuration has changed. Trying to upload to server.")
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.main.async {
        crtNotifiSetting.changeChangesButErrorUploading(newValue: false)
        group.leave()
    }
    group.wait()
    
    if let token = crtNotifiSetting.entity!.lastApnsToken {
        let newConfig = UploadPushNotificationConfigRepresentable(token, regionIdentifier, vatSelection, crtNotifiSetting.entity!)
        let requestSuccessful = uploadPushNotificationSettings(configuration: newConfig)
        
        if !requestSuccessful {
            DispatchQueue.main.async {
                crtNotifiSetting.changeChangesButErrorUploading(newValue: true)
            }
        }
    } else {
        print("No token is yet set. Will perform upload in background task later.")
        DispatchQueue.main.async {
            crtNotifiSetting.changeChangesButErrorUploading(newValue: true)
        }
    }
    crtNotifiSetting.currentlySendingToServer.unlock()
}

func initiateBackgroundNotificationUpdate(currentSetting: CurrentSetting, crtNotifiSetting: CurrentNotificationSetting) {
    if crtNotifiSetting.changesAndStaged == true {
        DispatchQueue.global(qos: .background).async {
            notificationConfigChanged(
                regionIdentifier: Int(currentSetting.entity!.regionIdentifier),
                vatSelection: currentSetting.entity!.pricesWithTaxIncluded ? 1 : 0,
                crtNotifiSetting)
            DispatchQueue.main.async {
                crtNotifiSetting.changesAndStaged = false
            }
        }
    }
}
