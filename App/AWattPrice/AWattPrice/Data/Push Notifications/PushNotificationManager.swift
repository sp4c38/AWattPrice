//
//  PushNotificationManager.swift
//  AWattPrice
//
//  Created by Léon Becker on 17.12.20.
//

import SwiftUI
import UIKit
import UserNotifications

func managePushNotificationsOnAppAppear(notificationAccessRepresentable: NotificationAccess, registerForRemoteNotifications: Bool) {
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
    var scheduleUpdate = false
    
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
        if self.scheduleUpdate == true {
            self.crtNotifiSetting!.currentlySendingToServer.lock()
            self.doNotificationUpdate()
        }
        currentlySleeping = false
    }
    
    func backgroundNotificationUpdate(currentSetting: CurrentSetting, crtNotifiSetting: CurrentNotificationSetting) {
        self.currentSetting = currentSetting
        self.crtNotifiSetting = crtNotifiSetting
        
        if self.crtNotifiSetting!.currentlySendingToServer.try() == true { // Currently not sending
            if self.currentlySleeping == false { // Don't need to wait
                backgroundQueue.async {
                    self.scheduleUpdate = false
                    self.doNotificationUpdate()
                    self.startTimer()
                }
            } else {
                self.scheduleUpdate = true
                self.crtNotifiSetting!.currentlySendingToServer.unlock()
            }
        } else {
            if !currentlySleeping {
                self.scheduleUpdate = true
            } else {
                backgroundQueue.async {
                    self.scheduleUpdate = false
                    self.startTimer()
                    self.crtNotifiSetting!.currentlySendingToServer.lock()
                    self.doNotificationUpdate()
                    self.startTimer()
                }
            }
        }
    }
}
