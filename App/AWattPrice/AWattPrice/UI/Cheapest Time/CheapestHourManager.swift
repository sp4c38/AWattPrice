//
//  CheapestHourManager.swift
//  AwattarApp
//
//  Created by Léon Becker on 22.10.20.
//

import Foundation

/// An object which manages the calculation of when the cheapest hours are for energy consumption
class CheapestHourManager: ObservableObject {
    @Published var inputMode = 0
    @Published var errorValues = [Int]()

    @Published var powerOutputString = ""
    @Published var powerOutput: Double = 0

    @Published var energyUsageString = ""
    @Published var energyUsage: Double = 0

    @Published var startDate = Date()
    @Published var endDate = Date().addingTimeInterval(3600)

    @Published var timeOfUsageInterval = TimeInterval(0)

    @Published var timeOfUsage: Int = 0

    @Published var cheapestHoursForUsage: HourPair? = nil

    /// Set to true if calculations have been performed but no cheapest hours could be found.
    @Published var errorOccurredFindingCheapestHours = false
}

extension CheapestHourManager {
    /// Sets the values after the user entered them.
    /// - Returns: If errors occur because of wrong input of the user and values cannot be set correctly a list is returned with error values.
    ///     - [0] all values were entered correctly
    ///     - [1] powerOutputString is empty
    ///     - [2] powerOutputString contains wrong characters
    ///     - [3] energyUsageString is empty
    ///     - [4] energyUsageString contains wrong characters
    ///     - [5] the time which is needed with current power output and energy usage is smaller than the time range specified.
    ///     - [6] not supported in this beta release
    func setValues() {
        errorValues = []
        cheapestHoursForUsage = nil
        if inputMode == 1 {
            if powerOutputString.replacingOccurrences(of: " ", with: "") == "" {
                errorValues.append(1)
            } else {
                if let powerOutputConverted = powerOutputString.doubleValue {
                    powerOutput = powerOutputConverted
                } else {
                    errorValues.append(2)
                }
            }

            if energyUsageString.replacingOccurrences(of: " ", with: "") == "" {
                errorValues.append(3)
            } else {
                if let energyUsageConverted = energyUsageString.doubleValue {
                    energyUsage = energyUsageConverted
                } else {
                    errorValues.append(4)
                }
            }
        }

        if errorValues.isEmpty {
            timeOfUsage = Int(timeOfUsageInterval)
            if inputMode == 1 {
                timeOfUsage = Int(
                    (energyUsage / powerOutput) * 60 * 60
                )
            }
            let timeRangeMax = Int(endDate.timeIntervalSince(startDate))
            if timeOfUsage > timeRangeMax {
                errorValues.append(5)
            }
        }

        if errorValues.isEmpty { errorValues.append(0) }
    }
}

extension CheapestHourManager {
    /// Sets the selected time interval to tonight from 20pm first day to 7am next day
    func setTimeIntervalThisNight(with energyData: EnergyData) {
        var possibleStartDate = Date()
        let currentHour = Calendar.current.component(.hour, from: possibleStartDate)

        if currentHour >= 20 || currentHour < 7 {
            possibleStartDate = Date()
        } else {
            possibleStartDate = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        }
        var firstPossibleStartDate = energyData.currentPrices.first!.startTime

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var possibleEndDate = Date()
        if currentHour >= 0, currentHour < 7 {
            possibleEndDate = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        } else {
            possibleEndDate = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!
        }
        let lastPossibleEndDate = energyData.currentPrices.last!.endTime

        if possibleStartDate >= firstPossibleStartDate, possibleStartDate <= lastPossibleEndDate {
            startDate = possibleStartDate
        } else {
            firstPossibleStartDate = Date()
            startDate = firstPossibleStartDate
        }

        if possibleEndDate > lastPossibleEndDate {
            endDate = lastPossibleEndDate
        } else {
            endDate = possibleEndDate
        }
    }

    /// Sets the selected time interval to the next x hours
    func setTimeInterval(forHours hourAmount: Int, with energyData: EnergyData) {
        startDate = Date()
        let possibleEndDate = Calendar.current.date(byAdding: .hour, value: hourAmount, to: Date())!
        let lastPossibleEndDate = energyData.currentPrices.last!.endTime

        if possibleEndDate > lastPossibleEndDate {
            endDate = lastPossibleEndDate
        } else {
            endDate = possibleEndDate
        }
    }

    func setMaxTimeInterval(with energyData: EnergyData) {
        startDate = Date()
        endDate = energyData.currentPrices.last!.endTime
        let calendar = Calendar.current

        if calendar.component(.hour, from: endDate) == 0, startDate > endDate {
            // Toggles if the last hour is the hour at midnight.
            // In this case subtract 60 s because the end date time selection
            // can't be set to 00:00 but needs to be set to 23:59.
            endDate.addTimeInterval(-60)
        }
    }
}

/// A pair of one, two, three or more EnergyPricePoints. This object supports functionallity to
/// calculate the average price and to calculate the prices for the hourly awattar tariff.
class HourPair {
    var averagePrice: Double = 0
    var associatedPricePoints: [EnergyPricePoint]
    /// Final energy cost which is calculated with a certain power (kW) a electrical
    /// consumer uses and the time of the usage.
    var hourlyEnergyCosts: Double?

    init(associatedPricePoints: [EnergyPricePoint]) {
        self.associatedPricePoints = associatedPricePoints
    }

    /// Caluclates the average price from the energy price of all to this HourPair
    /// associated price points without VAT included.
    func calculateAveragePrice() {
        var pricesTogether: Double = 0
        var totalMinutes: Double = 0
        for pricePoint in associatedPricePoints {
            let pricePointMinuteLength: Double = pricePoint.startTime
                .timeIntervalSince(pricePoint.endTime) / 60
            pricesTogether += pricePointMinuteLength * pricePoint.marketprice
            totalMinutes += pricePointMinuteLength
        }
        averagePrice = pricesTogether / totalMinutes
    }

//    func calculateHourlyPrice(currentSetting: CurrentSetting) {
//        hourlyEnergyCosts = nil
//        var hourlyPrice: Double = 0
//
//        if currentSetting.entity!.awattarTariffIndex == 0 {
//            for hourPair in associatedPricePoints {
//                let lengthOfIntervene = Double(abs(hourPair.endTimestamp - hourPair.startTimestamp)) / 60 / 60 // In hours
//                var price = hourPair.marketprice
//
//                if currentSetting.entity!.pricesWithVAT {
//                    price *= currentSetting.currentVATToUse
//                }
//
//                let basePrice: Double = lengthOfIntervene * currentSetting.entity!.awattarBaseElectricityPrice
//
//                hourlyPrice += (lengthOfIntervene * price) + basePrice
//            }
//
//            hourlyEnergyCosts = hourlyPrice
//        }
//    }
}

extension CheapestHourManager {
    func createHourPairs(forHours timeRangeNumber: Int, fromStartTime startTime: Date, toEndTime endTime: Date, with energyData: EnergyData) -> [HourPair] {
        // Create all HourPair's for later comparison
        var allPairs = [HourPair]()
        for hourIndex in 0 ..< energyData.currentPrices.count {
            if hourIndex + (timeRangeNumber - 1) <= energyData.currentPrices.count - 1 {
                let hourStartDate = energyData.currentPrices[hourIndex].startTime

                let maxHourThisPairEndDate = energyData.currentPrices[hourIndex + timeRangeNumber - 1].endTime

                if hourStartDate >= startTime, maxHourThisPairEndDate <= endTime {
                    let newPairNode = HourPair(associatedPricePoints: [energyData.currentPrices[hourIndex]])

                    for nextHourIndex in 1 ..< timeRangeNumber {
                        newPairNode.associatedPricePoints.append(energyData.currentPrices[hourIndex + nextHourIndex])
                    }

                    newPairNode.calculateAveragePrice()
                    allPairs.append(newPairNode)
                }
            }
        }

        return allPairs
    }
}

extension CheapestHourManager {
    func compareHourPairs(allPairs: [HourPair]) -> Int? {
        // Compare all hour pairs to find the index of the hour pair with the smallest average price
        var cheapestPairIndex: Int?
        for pairIndex in 0 ..< allPairs.count {
            if cheapestPairIndex != nil {
                if allPairs[pairIndex].averagePrice < allPairs[cheapestPairIndex!].averagePrice {
                    cheapestPairIndex = pairIndex
                }
            } else {
                cheapestPairIndex = pairIndex
            }
        }

        return cheapestPairIndex
    }
}

extension CheapestHourManager {
    /**
     Function to calculate when energy prices are cheapest.
     - Returns: Doesn't return value directly. Instead sets cheapestHoursForUsage of CheapestHourManager to the result HourPair.
     - Parameter energyData: Current energy data (data downloaded from the server)
     */
    func calculateCheapestHours(energyData: EnergyData, currentSetting _: CurrentSetting) {
        DispatchQueue.global(qos: .userInitiated).async {
            var startTime = self.startDate
            var endTime = self.endDate

            let timeRangeNumber = Int(
                (Double(self.timeOfUsage) / 3600)
                    .rounded(.up)
            )

            var startTimeDifference = 0
            var endTimeDifference = 0

            if Calendar.current.component(.minute, from: startTime) != 0 {
                startTimeDifference = Calendar.current.component(.minute, from: startTime)
                startTime = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: startTime),
                    minute: 0,
                    second: 0,
                    of: startTime
                )! // Set the minute and second of the start time both to zero
            }

            if Calendar.current.component(.minute, from: self.endDate) != 0 {
                endTimeDifference = Calendar.current.component(.minute, from: self.endDate)
                endTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: endTime), minute: 0, second: 0, of: endTime)!
                endTime = endTime.addingTimeInterval(3600)
                // Set the end time to the start of the next following hour
            }

            func recursiveSearch(with allPairs: [HourPair], lastCheapestPairIndex: Int? = nil) -> Int? {
                // logger.debug("Running recursive search to find cheapest time")
                var cheapestPairIndex = self.compareHourPairs(allPairs: allPairs)

                if cheapestPairIndex != nil {
                    if lastCheapestPairIndex != cheapestPairIndex {
                        var performAnotherSearch = false

                        let cheapestPair = allPairs[cheapestPairIndex!]
                        var maxPointIndex = cheapestPair.associatedPricePoints.count - 1

                        let startTimeHourEnd = startTime.addingTimeInterval(3600)
                        let endTimeHourStart = endTime.addingTimeInterval(-3600)
                        let startDateFirstItem = cheapestPair.associatedPricePoints.first!.startTime
                        let endDateLastItem = cheapestPair.associatedPricePoints.last!.endTime

                        var intervenesWithStartHour = false
                        if startDateFirstItem >= startTime, startDateFirstItem < startTimeHourEnd {
                            intervenesWithStartHour = true
                        }
                        var intervenesWithEndHour = false
                        if endDateLastItem > endTimeHourStart, endDateLastItem <= endTime {
                            intervenesWithEndHour = true
                        }

                        func searchAndAddFollowingItem(timestamp: Int) {
                            // Find next following energy price point
                            for item in energyData.currentPrices {
                                if Int(item.startTime.timeIntervalSince1970) == timestamp {
                                    cheapestPair.associatedPricePoints.append(item)
                                    // logger.debug("Found the missing energy price point with start timestamp \(item.startTimestamp).")
                                    break
                                }
                            }
                        }

                        if intervenesWithStartHour, !intervenesWithEndHour, startTimeDifference != 0 {
                            // logger.debug("Intervenes with start hour")
                            searchAndAddFollowingItem(timestamp: Int(endDateLastItem.timeIntervalSince1970))
                            maxPointIndex = cheapestPair.associatedPricePoints.count - 1

                            cheapestPair.associatedPricePoints[0].startTime =
                                cheapestPair.associatedPricePoints.first!.startTime.addingTimeInterval(
                                    TimeInterval(startTimeDifference * 60)
                                )
                            cheapestPair.associatedPricePoints[maxPointIndex].endTime =
                                cheapestPair.associatedPricePoints.last!.endTime.addingTimeInterval(
                                    TimeInterval(-((60 - startTimeDifference) * 60))
                                )
                            performAnotherSearch = true
                        }

                        func searchAndAddPreFollowingItem(timestamp: Int) {
                            // Find the pre-following price point
                            for item in energyData.currentPrices {
                                if Int(item.endTime.timeIntervalSince1970) == timestamp {
                                    // logger.debug("Found the missing energy price point with end timestamp \(item.endTimestamp).")
                                    cheapestPair.associatedPricePoints.insert(item, at: 0)
                                    break
                                }
                            }
                        }

                        if intervenesWithEndHour, !intervenesWithStartHour, endTimeDifference != 0 {
                            // logger.debug("Intervenes with end hour")
                            searchAndAddPreFollowingItem(timestamp: Int(startDateFirstItem.timeIntervalSince1970))
                            maxPointIndex = cheapestPair.associatedPricePoints.count - 1

                            cheapestPair.associatedPricePoints[maxPointIndex].endTime =
                                cheapestPair.associatedPricePoints.last!.endTime.addingTimeInterval(
                                    TimeInterval(-((60 - endTimeDifference) * 60))
                                )
                            cheapestPair.associatedPricePoints[0].startTime =
                                cheapestPair.associatedPricePoints.first!.startTime.addingTimeInterval(
                                    TimeInterval(endTimeDifference * 60)
                                )
                            performAnotherSearch = true
                        }

                        if intervenesWithStartHour, intervenesWithEndHour {
                            // logger.debug("Intervenes with both start and end hour")
                            // No need to change something
                        }

                        if performAnotherSearch {
                            cheapestPair.calculateAveragePrice()
                            cheapestPairIndex = recursiveSearch(with: allPairs, lastCheapestPairIndex: cheapestPairIndex)
                        }
                    }
                } else {
                    return nil
                }

                return cheapestPairIndex
            }

            let allPairs = self.createHourPairs(
                forHours: timeRangeNumber,
                fromStartTime: startTime,
                toEndTime: endTime,
                with: energyData
            )
            let results = recursiveSearch(with: allPairs)
            let cheapestHourPairIndex = results

            if cheapestHourPairIndex != nil {
                let cheapestPair = allPairs[cheapestHourPairIndex!]

                let timeRangeNumberInSeconds = timeRangeNumber * 3600
                let timeRangeDifference = Int(
                    (
                        Double(timeRangeNumberInSeconds - self.timeOfUsage)
                            / 60
                    )
                    .rounded()
                )

                if timeRangeDifference != 0 {
                    let maxPointIndex = cheapestPair.associatedPricePoints.count - 1

                    // If the user searches for a time with hours and minutes like 2,3h or 1h 40min than this if statment triggers.
                    if cheapestPair.associatedPricePoints[0].marketprice <= cheapestPair.associatedPricePoints[maxPointIndex].marketprice {
                        cheapestPair.associatedPricePoints[maxPointIndex].endTime =
                            cheapestPair.associatedPricePoints[maxPointIndex].endTime.addingTimeInterval(
                                TimeInterval(-(timeRangeDifference * 60))
                            )
                    } else {
                        cheapestPair.associatedPricePoints[0].startTime =
                            cheapestPair.associatedPricePoints[0].startTime.addingTimeInterval(
                                TimeInterval(timeRangeDifference * 60)
                            )
                    }
                }

//                if currentSetting.setting != nil {
//                    cheapestPair.calculateHourlyPrice(currentSetting: currentSetting)
//                }
            }

            DispatchQueue.main.async {
                if cheapestHourPairIndex != nil {
                    self.cheapestHoursForUsage = allPairs[cheapestHourPairIndex!]
                } else {
                    self.errorOccurredFindingCheapestHours = true
                }
            }
        }
    }
}
