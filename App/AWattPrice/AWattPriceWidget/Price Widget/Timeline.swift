////
////  Timeline.swift
////  AWattPriceWidgetExtension
////
////  Created by Léon Becker on 04.02.21.
////
//
//import Network
//import WidgetKit
//
///// Get the current energy data from the app storage. If this energy data needs to be updated or doesn't exist yet the backend is polled. If no energy data could be found at all a empty energy data object will be returned.
//fileprivate func getCurrentEnergyData(_ setting: CurrentSetting) -> EnergyData {
//    // Energy data with default values
//    var energyData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
//
//    let groupManager = AppGroupManager()
//    guard groupManager.setGroup(AppGroups.awattpriceGroup) == true else {
//        return energyData
//    }
//
//    let energyDataStored = groupManager.readEnergyData()
//    var storedDataNeedsUpdate = true
//    if energyDataStored != nil {
////        storedDataNeedsUpdate = checkEnergyDataNeedsUpdate(energyDataStored!)
//    }
//    storedDataNeedsUpdate = true
//    if storedDataNeedsUpdate {
//        guard let entity = setting.entity else { return energyData }
//
//        let backendCommunicator = BackendCommunicator()
//        let networkManager = NetworkManager(waitUntilFirstStatusWasRetrieved: true)
////        backendCommunicator.download(
////            groupManager, entity.regionIdentifier, networkManager, runAsync: false
////        )
//        guard let currentEnergyData = backendCommunicator.energyData else { return energyData }
//        energyData = currentEnergyData
//    }
//    return energyData
//}
//
///// Returns bool indicating if the app/widget should check for new data in near future.
//fileprivate func needToCheckForNewData(basedOn energyData: EnergyData, _ rotation: Rotation) -> Bool {
//    guard let lastItemStart = energyData.prices.last?.startTimestamp else { return true }
//    guard let rotationDate = rotation.rotationDate else { return true }
//
//    let now = Date()
//
//    let difference = Calendar.init(identifier: .gregorian).compare(lastItemStart, to: now, toGranularity: .day).rawValue
//    if difference > 0 {
//        return false
//    } else {
//        if now >= rotationDate {
//             return true
//        } else {
//            return false
//        }
//    }
//}
//
///** Creates the max. amount of price entries from the start of the following hour till the rotation time. A entry is created each n step seconds.
//*/
//fileprivate func priceEntriesUntilNextRoatationTime(
//    _ rotation: Rotation
//) -> [PriceWidgetEntry] {
//    guard let rotationTime = rotation.rotationDate else { return [] }
//    let tomorrowRotationTime = rotationTime + 86400
//
//    var entries = [PriceWidgetEntry]()
//
//    var hourCounter = Calendar.current.startOfHour(
//        for: Date() + 3600
//    ) // Starts with the start of the following hour
//
//    while hourCounter <= tomorrowRotationTime {
//        entries.append(PriceWidgetEntry(date: hourCounter))
//        hourCounter += rotation.noUpdateStepSeconds
//    }
//
//    return entries
//}
//
//fileprivate func checkStepAndRotationValid(_ rotation: Rotation) -> Bool {
//    let rotationHourSeconds = rotation.hour * 60 * 60
//    let rotationRemainder = rotationHourSeconds % Int(rotation.noUpdateStepSeconds)
//    if rotationRemainder != 0 {
//        return false
//    } else {
//        return true
//    }
//}
//
//fileprivate func priceEntriesForCheckNewData(_ rotation: Rotation) -> [PriceWidgetEntry] {
//    let entries = [
//        PriceWidgetEntry(date: Date() + rotation.updateStepSeconds)
//    ]
//
//    return entries
//}
//
//enum TimeLineError {
//    case stepAndRotationHourNotValid
//}
//
//fileprivate func priceEntryInOneHour() -> PriceWidgetEntry {
//    let nowInOneHour = Date().addingTimeInterval(3600)
//    let entry = PriceWidgetEntry(date: nowInOneHour)
//    return entry
//}
//
//fileprivate func getTimeLineWhenErrors(_ errors: [TimeLineError]) -> Timeline<PriceWidgetEntry> {
//    if errors.contains(.stepAndRotationHourNotValid) {
//        return Timeline(entries: [], policy: .never)
//    } else {
//        let entryInOneHour = priceEntryInOneHour()
//        let entries = [entryInOneHour]
//        return Timeline(entries: entries, policy: .atEnd)
//    }
//}
//
//func getNewPriceTimeline(
//    in context: TimelineProviderContext,
//    completion: @escaping (Timeline<PriceWidgetEntry>) -> ()
//) {
//    let persistence = PersistenceManager()
//    let setting = CurrentSetting(managedObjectContext: persistence.persistentContainer.viewContext)
//    let energyData = getCurrentEnergyData(setting)
//
//    var rotation: Rotation = Rotation(
//        hour: 13, minute: 0, second: 0, ofTimeZone: "Europe/Berlin", updateStepSeconds: 600,
//        noUpdateStepSeconds: 3600
//    )
//
//    var timelineErrors = [TimeLineError]()
//    if checkStepAndRotationValid(rotation) == false {
//        timelineErrors.append(.stepAndRotationHourNotValid)
//    }
//
//    var timeline: Timeline<PriceWidgetEntry>? = nil
//    if timelineErrors.isEmpty {
//        rotation.rotationDate = getTimeZoneTimeBySetting(
//            hour: rotation.hour, minute: rotation.minute, second: rotation.second, usingTimeZone: rotation.timeZoneID
//        ) // Set time after which AWattPrice should check for new energy data.
//        let needToCheckForNewData = needToCheckForNewData(basedOn: energyData, rotation)
//
//        var entries: [PriceWidgetEntry]? = nil
//        if needToCheckForNewData {
//            logger.debug("Getting price entries, knowing that new price data will soon be available.")
//            entries = priceEntriesForCheckNewData(rotation)
//        } else {
//            logger.debug("Getting price entries until next rotation time.")
//            entries = priceEntriesUntilNextRoatationTime(rotation)
//        }
//        timeline = Timeline(entries: entries!, policy: .atEnd)
//    } else {
//        logger.error("Timeline errors occurred: \(timelineErrors).")
//        timeline = getTimeLineWhenErrors(timelineErrors)
//    }
//
//    completion(timeline!)
//}
