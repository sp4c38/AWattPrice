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

func getTimeZoneTime(for rotation: Rotation, fromTimeZone timeZone: String) -> Date {
    let timeComponentFormatter = NumberFormatter()
    timeComponentFormatter.maximumIntegerDigits = 2
    let hourString = timeComponentFormatter.string(from: NSNumber(value: rotation.hour)) ?? "00"
    let minuteString = timeComponentFormatter.string(from: NSNumber(value: rotation.minute)) ?? "00"
    let secondString = timeComponentFormatter.string(from: NSNumber(value: rotation.second)) ?? "00"
    
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
fileprivate func needToCheckForNewData(basedOn energyData: EnergyData, _ rotation: Rotation) -> Bool {
    guard let lastItemStart = energyData.prices.last?.startTimestamp else { return true }
    guard let rotationDate = rotation.rotationDate else { return true }
    
    let now = Date()

    let difference = Calendar.init(identifier: .gregorian).compare(lastItemStart, to: now, toGranularity: .day).rawValue
    if difference > 0 {
        return false
    } else {
        if now >= rotationDate {
             return true
        } else {
            return false
        }
    }
}

/** Creates the max. amount of price entries from the start of the following hour till the rotation time. A entry is created each n step seconds.
*/
fileprivate func priceEntriesUntilNextRoatationTime(
    _ rotation: Rotation
) -> [PriceWidgetEntry] {
    guard let rotationTime = rotation.rotationDate else { return [] }
    var entries = [PriceWidgetEntry]()
    
    var hourCounter = Calendar.current.startOfHour(
        for: Date() + 3600
    ) // Starts with the start of the following hour
    
    while hourCounter <= rotationTime {
        entries.append(PriceWidgetEntry(date: hourCounter))
        hourCounter += rotation.stepSeconds
    }
    
    return entries
}


struct Rotation {
    var hour: Int
    var minute: Int
    var second: Int = 0
    var stepSeconds: TimeInterval
    var rotationDate: Date? = nil
}

fileprivate func checkStepAndRotationValid(_ rotation: Rotation) -> Bool {
    let rotationHourSeconds = rotation.hour * 60 * 60
    let rotationRemainder = Int(rotation.stepSeconds) % rotationHourSeconds
    if rotationRemainder != 0 {
        return false
    } else {
        return true
    }
}

fileprivate func priceEntriesForCheckNewData() -> [PriceWidgetEntry] {
    var entries = [PriceWidgetEntry]()
    
    let now = Date()
    let nowMinutes = Calendar.current.component(.minute, from: now)
    
    
    return entries
}

enum TimeLineError {
    case stepAndRotationHourNotValid
}

fileprivate func priceEntryInOneHour() -> PriceWidgetEntry {
    let nowInOneHour = Date().addingTimeInterval(3600)
    let entry = PriceWidgetEntry(date: nowInOneHour)
    return entry
}

fileprivate func getTimeLineWhenErrors(_ errors: [TimeLineError]) -> Timeline<PriceWidgetEntry> {
    if errors.contains(.stepAndRotationHourNotValid) {
        return Timeline(entries: [], policy: .never)
    } else {
        let entryInOneHour = priceEntryInOneHour()
        let entries = [entryInOneHour]
        return Timeline(entries: entries, policy: .atEnd)
    }
}

func getNewPriceTimeline(
    in context: TimelineProviderContext,
    completion: @escaping (Timeline<PriceWidgetEntry>) -> ()
) {
    // Get current persistently stored settings
    let persistence = PersistenceManager()
    let setting = CurrentSetting(managedObjectContext: persistence.persistentContainer.viewContext)
    let energyData = getCurrentEnergyData(setting)
    
    var timelineErrors = [TimeLineError]()
    
    var cetRotation: Rotation = Rotation(hour: 13, minute: 0, stepSeconds: 3600) // The hour, minute (in CET/CEST timezone) after which to check for new price data. If now < rotationHour or there already is new data for the following day, entries are created, apart of each other in the set step second interval.
    if checkStepAndRotationValid(cetRotation) == false {
        timelineErrors.append(.stepAndRotationHourNotValid)
    }
    
    var timeline: Timeline<PriceWidgetEntry>? = nil
    if timelineErrors.isEmpty {
        cetRotation.rotationDate = getTimeZoneTime(for: cetRotation, fromTimeZone: "Europe/Berlin") // Set time after which AWattPrice should check for new energy data.
        let needToCheckForNewData = needToCheckForNewData(basedOn: energyData, cetRotation)

        var entries: [PriceWidgetEntry]? = nil
        if needToCheckForNewData {
            entries = priceEntriesForCheckNewData()
        } else {
            entries = priceEntriesUntilNextRoatationTime(cetRotation)
        }
        timeline = Timeline(entries: entries!, policy: .atEnd)
    } else {
        timeline = getTimeLineWhenErrors(timelineErrors)
    }
    
    completion(timeline!)
    
    return
}
