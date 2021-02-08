//
//  Timeline.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 04.02.21.
//

import Network
import WidgetKit

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

func getTimeZoneTime(hour: Int, minute: Int, second: Int, fromTimeZone timeZone: String) -> Date {
    let timeComponentFormatter = NumberFormatter()
    timeComponentFormatter.maximumIntegerDigits = 2
    let hourString = timeComponentFormatter.string(from: NSNumber(value: hour)) ?? "00"
    let minuteString = timeComponentFormatter.string(from: NSNumber(value: minute)) ?? "00"
    let secondString = timeComponentFormatter.string(from: NSNumber(value: second)) ?? "00"
    
    let isoDateFormatter = DateFormatter()
    isoDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    isoDateFormatter.timeZone = TimeZone(identifier: "Europe/Berlin")
    let nowBerlinISO = isoDateFormatter.string(from: Date())
    
    let noonTimeDate = nowBerlinISO.prefix(11)
    let noonTimeTime = "\(hourString):\(minuteString):\(secondString)"
    let noonTimeTimezone = nowBerlinISO.suffix(6)
    let noonTimeZoneISO = String(noonTimeDate + noonTimeTime + noonTimeTimezone)
    
    let noonDateFormatter = DateFormatter()
    noonDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    let noon = noonDateFormatter.date(from: noonTimeZoneISO)
    return noon!
}

/// Returns bool indicating if the app/widget should check for new data in near future.
fileprivate func needToCheckForNewData(basedOn energyData: EnergyData, withRotationTime rotationTime: Date) -> Bool {
    guard let lastItemStart = energyData.prices.last?.startTimestamp else { return true }
    
    let now = Date()

    let difference = Calendar.init(identifier: .gregorian).compare(lastItemStart, to: now, toGranularity: .day).rawValue
    if difference > 0 {
        return false
    } else {
        if now >= rotationTime {
             return true
        } else {
            return false
        }
    }
}

func getNewPriceTimeline(
    in context: TimelineProviderContext,
    completion: @escaping (Timeline<PriceWidgetEntry>) -> ()
) {
    // Get current persistently stored settings
    let persistence = PersistenceManager()
    let setting = CurrentSetting(managedObjectContext: persistence.persistentContainer.viewContext)
    var energyData = getCurrentEnergyData(setting)
    let rotationTime = getTimeZoneTime(hour: 12, minute: 0, second: 0, fromTimeZone: "Europe/Berlin") // Set time after which AWattPrice should check for new energy data.
    let needToCheckForNewData = needToCheckForNewData(basedOn: energyData, withRotationTime: rotationTime)

    var entries = [PriceWidgetEntry]()
    let timeline: Timeline<PriceWidgetEntry>? = nil
    if needToCheckForNewData {
        
    } else {
        timeline = timelineUntilNextRotationTime(rotationTime)
    }
    
    completion(timeline!)
    return
}
