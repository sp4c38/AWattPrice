//
//  Timeline.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 04.02.21.
//

import Network
import WidgetKit

func getNewEnergyData() {
    
}

//func checkNeedContinuousUpdating(_ energyData: EnergyData) -> Bool {
//
//}

fileprivate func getPriceEntryInOneHour() -> PriceEntry? {
    guard let startMinute = Calendar.current.date(bySetting: .minute, value: 0, of: Date()) else { return nil }
    guard let startHour = Calendar.current.date(bySetting: .second, value: 0, of: startMinute) else { return nil }
    let nextHour = startHour.addingTimeInterval(3600)
    
    let entry = PriceEntry(date: nextHour)
    return entry
}

/// Get the current energy data from the app storage. If this energy data needs to be updated or doesn't exist yet the backend is polled. If no energy data could be found at all a a empty energy data object will be returned.
fileprivate func getCurrentEnergyData(_ setting: CurrentSetting) -> EnergyData {
    // Energy data with default values
    var energyData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
    
    let groupManager = AppGroupManager()
    guard groupManager.setGroup(AppGroups.awattpriceGroup) == true else {
        return energyData
    }
    
    let energyDataStored = groupManager.readEnergyData()
    var storedDataNeedsUpdate = true
    if energyDataStored != nil {
        storedDataNeedsUpdate = checkEnergyDataNeedsUpdate(energyDataStored!)
    }
    storedDataNeedsUpdate = true
    if storedDataNeedsUpdate {
        guard let entity = setting.entity else { return energyData }
        
        let backendCommunicator = BackendCommunicator()
        let networkManager = NetworkManager(waitUntilFirstStatusWasRetrieved: true)
        backendCommunicator.download(
            groupManager, entity.regionIdentifier, networkManager, runAsync: false
        )
        guard let currentEnergyData = backendCommunicator.energyData else { return energyData }
        energyData = currentEnergyData
    }
    
    return energyData
}

func getNewPriceTimeline(
    in context: TimelineProviderContext,
    completion: @escaping (Timeline<PriceEntry>) -> ()
) {
    // Get current persistently stored settings
    let persistence = PersistenceManager()
    let setting = CurrentSetting(managedObjectContext: persistence.persistentContainer.viewContext)
    var currentEnergyData: EnergyData? = nil
    
    if setting.entity != nil {
        currentEnergyData = getCurrentEnergyData(setting)
    }

    guard let energyData = currentEnergyData else {
        var entries = [PriceEntry]()
        let newEntry = getPriceEntryInOneHour()

        var timeline = Timeline(entries: entries, policy: .never)
        if newEntry != nil {
            entries.append(newEntry!)
            timeline = Timeline(entries: entries, policy: .atEnd)
        }
        completion(timeline)
        return
    }
//    let needContinuousUpdating = checkNeedContinuousUpdating(energyData)
}
