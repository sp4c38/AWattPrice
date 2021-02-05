//
//  Timeline.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 04.02.21.
//

import WidgetKit

func getNewEnergyData() {
    
}

//func checkNeedContinuousUpdating(_ energyData: EnergyData) -> Bool {
//
//}

fileprivate func checkStoredEnergyDataNeedsUpdate(_ energyData: EnergyData) -> Bool {
    guard let firstItem = energyData.prices.first else { return true }
    let now = Date()
    if now >= firstItem.startTimestamp, now < firstItem.endTimestamp {
        return false
    } else {
        return true
    }
}

fileprivate func getCurrentEnergyData(_ setting: CurrentSetting) -> EnergyData? {
    let groupManager = AppGroupManager()
    _ = groupManager.setGroup(AppGroups.awattpriceGroup)
    let currentEnergyDataStored = groupManager.readEnergyDataFromGroup()
    
    var energyData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
    var appStorageDataNeedsUpdate = false
    
    if currentEnergyDataStored != nil {
        appStorageDataNeedsUpdate = checkStoredEnergyDataNeedsUpdate(currentEnergyDataStored!)
        if !appStorageDataNeedsUpdate {
            energyData = currentEnergyDataStored!
        }
    }
    if appStorageDataNeedsUpdate || currentEnergyDataStored == nil {
        guard let entity = setting.entity else { return nil }
        let backendCommunicator = BackendCommunicator()
        backendCommunicator.download(
            groupManager, entity.regionIdentifier, NetworkManager(), runAsync: false
        )
        guard let currentEnergyData = backendCommunicator.energyData else { return nil }
        energyData = currentEnergyData
    }
    
    return energyData
}

fileprivate func getPriceEntryInOneHour() -> PriceEntry? {
    guard let startMinute = Calendar.current.date(bySetting: .minute, value: 0, of: Date()) else { return nil }
    guard let startHour = Calendar.current.date(bySetting: .second, value: 0, of: startMinute) else { return nil }
    let nextHour = startHour.addingTimeInterval(3600)
    
    let entry = PriceEntry(date: nextHour)
    return entry
}

func makeNewPriceTimeline(
    in context: TimelineProviderContext,
    completion: @escaping (Timeline<PriceEntry>) -> ()
) {
    let persistence = PersistenceManager()
    let setting = CurrentSetting(persistence.persistentContainer.viewContext)
    var currentEnergyData: EnergyData? = nil
    if setting.entity != nil {
        currentEnergyData = getCurrentEnergyData(setting)
        print(currentEnergyData)
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
