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
//
//func getCurrentSettings() -> CurrentSetting {
//
//}

func checkAndGetCurrentEnergyData(_ setting: CurrentSetting) -> EnergyData? {
    let groupManager = AppGroupManager()
    let currentEnergyDataStored = groupManager.readEnergyDataFromGroup()
    var currentEnergyData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
    
    if currentEnergyDataStored != nil {
        currentEnergyData = currentEnergyDataStored!
    } else {
        let backendCommunicator = BackendCommunicator()
        guard let entity = setting.entity else { return nil }
        backendCommunicator.download(
            groupManager, entity.regionIdentifier, NetworkManager()
        )
    }
    
    return currentEnergyData
}

func getPriceEntryInOneHour() -> PriceEntry? {
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
    let autoUpdatingEntity = AutoUpdatingEntity(
        entityName: "Setting", managedObjectContext: persistence.persistentContainer.viewContext
    )
    let currentEnergyData = checkAndGetCurrentEnergyData(currentSetting)

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
    let needContinuousUpdating = checkNeedContinuousUpdating(energyData)

    let currentDate = Date()
    for hourOffset in 0 ..< 5 {
        let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
        let entry = PriceEntry(date: entryDate)
        entries.append(entry)
    }
    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
}
