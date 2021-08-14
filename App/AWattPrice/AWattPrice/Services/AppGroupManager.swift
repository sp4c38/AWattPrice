//
//  AppGroup.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 31.01.21.
//

import SwiftUI

//enum AppGroups {
//    static let awattpriceGroup: String = {
////        return GlobalAppSettings.awattpriceGroupID
//        return ""
//    }()
//}
//
//class AppGroupManager {
//    var groupID: String
//    var containerURL: URL
//
//    init?(withID groupID: String) {
//        self.groupID = groupID
//        self.containerURL = URL(fileURLWithPath: "")
//
//        guard let newContainerURL = getContainerURL(groupID) else {
//            logger.error("A group container with the supplied ID \(groupID) doesn't exist.")
//            return nil
//        }
//        containerURL = newContainerURL
//    }
//
//    private func getContainerURL(_ containerID: String) -> URL? {
//        let newContainerURL = FileManager.default.containerURL(
//            forSecurityApplicationGroupIdentifier: containerID
//        )
//        guard let containerURL = newContainerURL else { return nil }
//        return containerURL
//    }
//
//    internal func regionToFileName(_ region: Region) -> String {
//        let rootNamePrefix = "EnergyData_"
//        var regionName = ""
//        let rootNameSuffix = ".json"
//
//        if region == .DE {
//            regionName = "DE"
//        } else if region == .AT {
//            regionName = "AT"
//        }
//
//        return rootNamePrefix + regionName + rootNameSuffix
//    }
//
//    enum ReadWriteError: Error {
//        case readFromFileError
//        case writeEncodingError
//        case writeToFileError
//    }
//
//    public func writeEnergyDataToGroup(_ energyData: EnergyData) throws {
//        guard let encodedData = quickJSONEncode(energyData, setEncoder: { jsonEncoder in
//            jsonEncoder.dateEncodingStrategy = .secondsSince1970
//        }) else { throw ReadWriteError.writeEncodingError }
//
//        let region = energyData.region
//        let storeURL = containerURL.appendingPathComponent(regionToFileName(region))
//
//        do {
//            try encodedData.write(to: storeURL)
//            logger.debug("Wrote energy data to group container.")
//        } catch {
//            logger.error("Couldn't write energy data to app group container: \(error.localizedDescription).")
//            throw ReadWriteError.writeToFileError
//        }
//        return
//    }
//
//    public func getEnergyDataStored(for region: Region) -> (Data?, Error?) {
//        let storeURL = containerURL.appendingPathComponent(regionToFileName(region))
//
//        var data = Data()
//        do {
//            data = try Data(contentsOf: storeURL)
//            logger.debug("Read stored energy data.")
//        } catch {
//            // Triggered if file doesn't exist yet (e.g.: on very first app launch).
//            logger.info("Couldn't read file with energy data from app group container: \(error.localizedDescription)")
//            return (nil, ReadWriteError.readFromFileError)
//        }
//        return (data, nil)
//    }
//}
