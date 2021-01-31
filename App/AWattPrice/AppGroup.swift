//
//  AppGroup.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 31.01.21.
//

import SwiftUI

enum AppGroups {
    static let awattpriceGroup: String = {
        return GlobalAppSettings.awattpriceGroupID
    }()
}

class AppGroupManager {
    var groupID: String? = nil
    var containerURL: URL? = nil
    
    private func getContainerURL(_ containerID: String) -> URL? {
        let newContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: containerID
        )
        guard let containerURL = newContainerURL else { return nil }
        return containerURL
    }
    
    public func setGroup(_ newGroupID: String) -> Bool {
        guard let newContainerURL = getContainerURL(newGroupID) else { return false }
        groupID = newGroupID
        containerURL = newContainerURL
        return true
        
    }
    
    public func writeEnergyDataToGroup(energyData: EnergyData) -> Bool {
        guard let parentURL = containerURL else { return false }
        print(parentURL)
        let storeURL = parentURL.appendingPathComponent("EnergyData.json")
        print(storeURL)
        return true
    }
}

class AppGroupManagerKey: EnvironmentKey {
    static var defaultValue = AppGroupManager()
}

extension EnvironmentValues {
    var appGroupManager: AppGroupManager {
        get { self[AppGroupManagerKey.self] }
        set {}
    }
}
