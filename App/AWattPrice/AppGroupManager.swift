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
    
    private var energyStoreFileName = "EnergyData.json"
    
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
        let encoder = JSONEncoder()
        var encodedEnergyData: Data?
        do {
            encodedEnergyData = try encoder.encode(energyData)
        } catch {
            print("Could encode energy data when writing to app group container: \(error).")
            return false
        }
        let storeURL = parentURL.appendingPathComponent("EnergyData.json")
        do {
            try encodedEnergyData!.write(to: storeURL)
        } catch {
            print("Couldn't write energy data to app group container: \(error).")
            return false
        }
        return true
    }
    
    public func readEnergyDataFromGroup() -> EnergyData? {
        guard let parentURL = containerURL else { return nil }
        let storeURL = parentURL.appendingPathComponent("EnergyData.json")
        var encodedEnergyData = Data()
        do {
            encodedEnergyData = try Data(contentsOf: storeURL)
        } catch {
            print("Couldn't read energy data from app group container: \(error).")
            return nil
        }
        let decoder = JSONDecoder()
        var decodedEnergyData: EnergyData? = nil
        do {
            decodedEnergyData = try decoder.decode(EnergyData.self, from: encodedEnergyData)
        } catch {
            print("Couldn't decode energy data after reading from app group container: \(error).")
        }
        return decodedEnergyData!
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
