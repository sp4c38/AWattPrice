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
        guard groupID != newGroupID else { return true }
        guard let newContainerURL = getContainerURL(newGroupID) else { return false }
        groupID = newGroupID
        containerURL = newContainerURL
        return true
        
    }
    
    public func writeEnergyDataToGroup(energyData: EnergyData) -> Bool {
        guard let parentURL = containerURL else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        var encodedEnergyData: Data?
        do {
            encodedEnergyData = try encoder.encode(energyData)
        } catch {
            logger.error("Could encode energy data when writing to app group container: \(error.localizedDescription).")
            return false
        }
        let storeURL = parentURL.appendingPathComponent("EnergyData.json")
        do {
            try encodedEnergyData!.write(to: storeURL)
            logger.debug("Wrote energy data to group container.")
        } catch {
            logger.error("Couldn't write energy data to app group container: \(error.localizedDescription).")
            return false
        }
        return true
    }
    
    public func readEnergyDataFromGroup() -> EnergyData? {
        guard let parentURL = containerURL else {
            logger.notice("No app group set when trying to read energy data from app group container..")
            return nil
        }
        let storeURL = parentURL.appendingPathComponent("EnergyData.json")
        var encodedEnergyData = Data()
        do {
            encodedEnergyData = try Data(contentsOf: storeURL)
        } catch {
            // Triggered if EnergyData.json doesn't yet exist.
            logger.info("Couldn't read file with energy data from app group container: \(error.localizedDescription).")
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        var decodedEnergyData: EnergyData? = nil
        do {
            decodedEnergyData = try decoder.decode(EnergyData.self, from: encodedEnergyData)
            logger.debug("Read energy data from group container.")
        } catch {
            logger.error("Couldn't decode energy data after reading from app group container: \(error.localizedDescription).")
        }
        guard let energyData = decodedEnergyData else { return nil }
        return energyData
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
