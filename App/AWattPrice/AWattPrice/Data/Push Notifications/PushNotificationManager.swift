//
//  PushNotificationManager.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import SwiftUI
import UIKit
import UserNotifications

func managePushNotificationsOnAppAppear(notificationAccessRepresentable: NotificationAccess, registerForRemoteNotifications: Bool, completionHandler: @escaping () -> Void) {
    DispatchQueue.global(qos: .background).async {
        let notificationAccess = checkNotificationAccess()
        if notificationAccess == true && registerForRemoteNotifications {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        
        if notificationAccess {
            notificationAccessRepresentable.access = true
        } else {
            notificationAccessRepresentable.access = false
        }
        
        completionHandler()
    }
}

/// Checks if AWattPrice is allowed to send notifications to the user.
func checkNotificationAccess() -> Bool {
    var returnResponse: Bool = false
    
    let dispatchSemaphore = DispatchSemaphore(value: 0)
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { successful, error in
        if successful == true && error == nil {
            print("Notification center access was granted.")
            returnResponse = true
        } else if successful == false && error == nil {
            print("Notification center access was rejected.")
            returnResponse = false
        } else if error != nil {
            print("Notification center access failed with error: \(error?.localizedDescription ?? "[Couldn't unpack optional as localized description]").")
            returnResponse = false
        }

        dispatchSemaphore.signal()
    }
    dispatchSemaphore.wait()
    
    return returnResponse
}

class PushNotificationUpdateManager {
    let backgroundQueue: DispatchQueue
    var currentlySleeping = false
    let updateInterval = 5 // In seconds
    var updateScheduled = false
    
    var crtNotifiSetting: CurrentNotificationSetting? = nil
    var currentSetting: CurrentSetting? = nil
    
    
    init() {
        let backgroundQueueName = "PushNotificationUpdateQueue"
        self.backgroundQueue = DispatchQueue.init(label: backgroundQueueName)
    }
    
    func notificationConfigChanged(regionIdentifier: Int, vatSelection: Int, _ crtNotifiSetting: CurrentNotificationSetting) {
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
            print("No token is set yet. Will perform upload in background task later.")
        }
        
        self.crtNotifiSetting!.currentlySendingToServer.unlock()
    }
    
    
    func doNotificationUpdate() {
        self.notificationConfigChanged(
            regionIdentifier: Int(self.currentSetting!.entity!.regionIdentifier),
            vatSelection: self.currentSetting!.entity!.pricesWithVAT ? 1 : 0,
            crtNotifiSetting!)
    }
    
    func startTimer() {
        currentlySleeping = true
        sleep(UInt32(updateInterval))
        currentlySleeping = false
    }
    
    func backgroundNotificationUpdate(currentSetting: CurrentSetting, crtNotifiSetting: CurrentNotificationSetting) {
        self.currentSetting = currentSetting
        self.crtNotifiSetting = crtNotifiSetting
        
        if self.currentlySleeping == false { // Don't need to wait
            backgroundQueue.async {
                self.crtNotifiSetting!.currentlySendingToServer.lock() // Make sure no task is sending data to the backend
                self.updateScheduled = false
                self.doNotificationUpdate()
                self.crtNotifiSetting!.changesAndStaged = false
                self.startTimer()
            }
        } else {
            if self.updateScheduled == false {
                updateScheduled = true
                backgroundQueue.async {
                    self.updateScheduled = false
                    self.doNotificationUpdate()
                    self.crtNotifiSetting!.changesAndStaged = false
                    self.startTimer()
                }
            } else {} // Don't need to do anything. Values were set before.
        }
    }
}
