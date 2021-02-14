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
    var groupID: String
    var containerURL: URL
    
    init?(withID groupID: String) {
        self.groupID = groupID
        self.containerURL = URL(fileURLWithPath: "")
        
        guard let newContainerURL = getContainerURL(groupID) else {
            logger.error("A group container with the supplied ID \(groupID) doesn't exist.")
            return nil
        }
        containerURL = newContainerURL
    }
    
    private func getContainerURL(_ containerID: String) -> URL? {
        let newContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: containerID
        )
        guard let containerURL = newContainerURL else { return nil }
        return containerURL
    }
    
    internal func regionToFileName(_ region: Region) -> String {
        let rootNamePrefix = "EnergyData_"
        var regionName = ""
        let rootNameSuffix = ".json"
        
        if region == .DE {
            regionName = "DE"
        } else if region == .AT {
            regionName = "AT"
        }
        
        return rootNamePrefix + regionName + rootNameSuffix
    }
    
    enum ReadWriteError: Error {
        case readFromFileError
        case writeEncodingError
        case writeToFileError
    }
    
    public func writeEnergyDataToGroup(energyData: EnergyData, forRegion region: Region) -> Error? {
        // Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        var encodedEnergyData: Data?
        do {
            encodedEnergyData = try encoder.encode(energyData)
        } catch {
            logger.error("Could encode energy data when writing to app group container: \(error.localizedDescription).")
            return ReadWriteError.writeEncodingError
        }
        
        // Write to file
        let storeURL = containerURL.appendingPathComponent("EnergyData.json")
        do {
            try encodedEnergyData!.write(to: storeURL)
            logger.debug("Wrote energy data to group container.")
        } catch {
            logger.error("Couldn't write energy data to app group container: \(error.localizedDescription).")
            return ReadWriteError.writeToFileError
        }
        return nil
    }
    
    public func getEnergyDataStored(for region: Region) -> (Data?, Error?) {
        let storeURL = containerURL.appendingPathComponent(regionToFileName(region))
        
        var data = Data()
        do {
            data = try Data(contentsOf: storeURL)
        } catch {
            // Triggered if EnergyData.json doesn't yet exist.
            logger.info("Couldn't read file with energy data from app group container: \(error.localizedDescription).")
            return (nil, ReadWriteError.readFromFileError)
        }
        return (data, nil)
    }
}
