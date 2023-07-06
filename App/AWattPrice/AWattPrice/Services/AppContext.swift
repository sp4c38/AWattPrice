//
//  AppContext.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.08.21.
//

import Foundation

class AppContext {
    static var shared = AppContext()
    
    var apiURL: URL = {
        #if DEBUG
        return URL(string: "https://test-awp.space8.me/api/v2/")!
        #else
        return URL(string: "https://awattprice.space8.me/api/v2/")!
        #endif
    }()
    
    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    func checkShowWhatsNewScreen() -> Bool {
        let savedVersion = UserDefaults.standard.string(forKey: "whatsNewScreenSavedAppVersion")

        if savedVersion != currentAppVersion, currentAppVersion == "1.4" {
            print("Detected app version update from \(savedVersion ?? "nil (first app launch with version tracking") to 1.4. Showing \"What's New?\" screen for version 1.4.")
            UserDefaults.standard.set(currentAppVersion, forKey: "whatsNewScreenSavedAppVersion")
            return true
        } else {
            print("App version didn't change from last start or doesn't qualify for display of the \"What's New?\" screen. Current app version: \(currentAppVersion); saved app version: \(String(describing: savedVersion)).")
            UserDefaults.standard.set(currentAppVersion, forKey: "whatsNewScreenSavedAppVersion")
            return false
        }
    }
}
