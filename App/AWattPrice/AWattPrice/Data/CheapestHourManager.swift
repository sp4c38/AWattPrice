//
//  CheapestHourManager.swift
//  AwattarApp
//
//  Created by Léon Becker on 22.10.20.
//

import Foundation

/// An object which manages the calculation of when the cheapest hours are for energy consumption
class CheapestHourManager: ObservableObject {
    // The power output of the electric device in kW
    @Published var powerOutputString = ""
    @Published var powerOutput: Double = 0
    
    // The energy usage the electric device shall consume in kWh
    @Published var energyUsageString = ""
    @Published var energyUsage: Double = 0
    
    // Time range from startDate to endDate in which to find the cheapest hours
    @Published var startDate = Date()
    @Published var endDate = Date().addingTimeInterval(3600)
    
    @Published var timeOfUsage: Double = 0
    
    /// The results of the calculation of the cheapest hours for usage which are represented in an HourPair object.
    @Published var cheapestHoursForUsage: HourPair? = nil
    /// A variable set to true if calculations have been performed but no cheapest hours were found.
    @Published var errorOccurredFindingCheapestHours = false
    
    /// Sets the selected time interval to tonight from 20pm first day to 7am next day
    func setTimeIntervalThisNight() {
        self.startDate = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        self.endDate = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!
    }
    
    /// Sets the selected time interval to tonight from 20pm first day to 7am next day
    func setTimeIntervalNextThreeHours() {
        self.startDate = Date()
        self.endDate = Calendar.current.date(byAdding: .hour, value: 3, to: Date())!
    }
    
    /// Sets the values after the user entered them. This includes calculating time intervals and formatting raw text strings to floats. If errors occur because of wrong input of the user and values cannot be set correctly a list is returned with error values.
    /// - Returns: Returns a list with error values if any occur. If no errors occur a list is also returned but with a success value
    ///     - [0] all values were entered correctly
    ///     - [1] powerOutputString is empty
    ///     - [2] powerOutputString contains wrong characters
    ///     - [3] energyUsageString is empty
    ///     - [4] energyUsageString contains wrong characters
    ///     - [5] the time which is needed with current power output and energy usage is smaller than the time range specified
    func setValues() -> [Int] {
        self.cheapestHoursForUsage = nil
        var errorValues = [Int]()
        
        if powerOutputString.replacingOccurrences(of: " ", with: "") == "" {
            errorValues.append(1)
        } else {
            if let powerOutputConverted = powerOutputString.doubleValue {
                self.powerOutput = powerOutputConverted
            } else {
                errorValues.append(2)
            }
        }
        
        if energyUsageString.replacingOccurrences(of: " ", with: "") == "" {
            errorValues.append(3)
        } else {
            if let energyUsageConverted = energyUsageString.doubleValue {
                self.energyUsage = energyUsageConverted
            } else {
                errorValues.append(4)
            }
        }

        if !(errorValues.count > 0) {
            let timeOfUsageInSeconds = (self.energyUsage / self.powerOutput) * 60 * 60
            let timeRangeMax = abs(self.startDate.timeIntervalSince(endDate))
            
            if (timeOfUsageInSeconds) <= timeRangeMax {
                self.timeOfUsage = timeOfUsageInSeconds / 60 / 60 // Convert time of usage back to hours
            } else {
                self.timeOfUsage = timeOfUsageInSeconds / 60 / 60 // Also set the time of usage even if an error occurres to help to deliver a better error message
                errorValues.append(5)
            }
        }

        if !(errorValues.count > 0) {
            errorValues.append(0)
        }
        
        return errorValues
    }
    
    /// A pair of one, two, three or more EnergyPricePoints. This object supports functionallity to calculate the average price or to sort the associated price points for day.
    class HourPair {
        var averagePrice: Float = 0
        var associatedPricePoints: [EnergyPricePoint]
        /// Final energy cost which is calculated with a certain power (kW) a electrical consumer uses and the time of the usage.
        var hourlyEnergyCosts: Float? = nil
        
        init(associatedPricePoints: [EnergyPricePoint]) {
            self.associatedPricePoints = associatedPricePoints
        }
        
        /// Caluclates the average price from the energy price of all to this HourPair associated price points without VAT included.
        func calculateAveragePrice() {
            var pricesTogether: Float = 0
            for pricePoint in self.associatedPricePoints {
                pricesTogether += pricePoint.marketprice
            }
            self.averagePrice = pricesTogether / Float(associatedPricePoints.count)
        }
        
        /// Calculates the average price from the energy price of all to this HourPair associated price points with VAT included.
        func countAllPricesTogether(withVat: Bool) -> Float {
            var pricesTogether: Float = 0
            for pricePoint in self.associatedPricePoints {
                if withVat {
                    pricesTogether += (pricePoint.marketprice * 1.16)
                } else {
                    pricesTogether += pricePoint.marketprice
                }
            }
            return pricesTogether
        }
    }
    
    func calculateHourlyPrice(cheapestHourPair: HourPair, currentSetting: CurrentSetting) -> HourPair {
        if currentSetting.setting!.awattarTariffIndex == 0 {
            let electricityPriceNoBonus = Double(cheapestHourPair.associatedPricePoints.count) * currentSetting.setting!.awattarBaseElectricityPrice
            if currentSetting.setting!.pricesWithTaxIncluded {
                cheapestHourPair.hourlyEnergyCosts = Float(electricityPriceNoBonus) + cheapestHourPair.countAllPricesTogether(withVat: true)
                
            } else {
                cheapestHourPair.hourlyEnergyCosts = Float(electricityPriceNoBonus) + cheapestHourPair.countAllPricesTogether(withVat: false)
            }
        }
        return cheapestHourPair
    }
    
    /**
     Function to calculate when energy prices are cheapest.
     - Returns: Doesn't return value directly. Instead sets cheapestHoursForUsage of CheapestHourManager to the result HourPair.
     - Parameter energyData: Current energy data (data downloaded from the server)
     */
    func calculateCheapestHours(energyData: EnergyData, currentSetting: CurrentSetting) {
        /*
         Description of how the cheapest hours are found:
            1. The algorithm firstly creates hour pairs.
                For example:
                    The user wants to find the most cheapest hours for a duration of 3 hours. The algorithm than would pack the EnergyPricePoint's held in energyData at 0, 1, 2 index in one HourPair. Than the items at 1, 2, 3 index. Than the items at 2, 3, 4 index and so on. Notice that always three items are packed together because the user wants to find cheapest hours for a duration of 3 hours. If there is a HourPair which can't be filled with exactly 3 energy price data points it won't be created (this can just happen at the end of the iteration).
                    Also while these HourPair's are created the average price of all with the HourPair associated EnergyPricePoint's are calculated.
            2. The algorithm find the cheapest HourPair by comparing all average prices of all HourPair's with each other. The HourPair with the smallest average price is the cheapest HourPair.
            3. If the user for example specified to find the cheapest hours for the duration of 3,5 hours, HourPairs with 4 items are created. Then the algorithm checks if the first 30 minutes or the last 30 minutes are cheaper and accordingly takes away 30 minutes of the first EnergyPricePoint or 30 minutes of the last EnergyPricePoint. If the user only wants to find the cheapest energy prices for full hours than this step doesn't matter.
         */
        
        DispatchQueue.global(qos: .userInitiated).async {
            var startTime = self.startDate
            var endTime = self.endDate
            let timeRangeNumber = Int(self.timeOfUsage.rounded(.up))
            
            var startTimeDifference = 0
            var endTimeDifference = 0
            
            if Calendar.current.component(.minute, from: startTime) != 0 {
                startTimeDifference = Calendar.current.component(.minute, from: startTime)
                startTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: startTime), minute: 0, second: 0, of: startTime)!
            }
            
            if Calendar.current.component(.minute, from: self.endDate) != 0 {
                endTimeDifference = Calendar.current.component(.minute, from: self.endDate)
                endTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: endTime), minute: 0, second: 0, of: endTime)!
                endTime = endTime.addingTimeInterval(3600)
                
            }
            
            // Create all HourPair's for later comparison
            var allPairs = [HourPair]()
            for hourIndex in 0..<energyData.prices.count {
                if hourIndex + (timeRangeNumber - 1) <= energyData.prices.count - 1 {
                    let hourStartDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[hourIndex].startTimestamp))

                    let maxHourThisPairEndDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[hourIndex + timeRangeNumber - 1].endTimestamp))
                    
                    if hourStartDate >= startTime && maxHourThisPairEndDate <= endTime {
                        let newPairNode = HourPair(associatedPricePoints: [energyData.prices[hourIndex]])

                        for nextHourIndex in 1..<timeRangeNumber {
                            newPairNode.associatedPricePoints.append(energyData.prices[hourIndex + nextHourIndex])
                        }

                        newPairNode.calculateAveragePrice()
                        allPairs.append(newPairNode)
                    }
                }
            }
            
            // Compare all hour pairs to find the index of the hour pair with the smallest average price
            var cheapestHourPairIndex: Int? = nil
            for pairIndex in 0..<allPairs.count {
                if cheapestHourPairIndex != nil {
                    if allPairs[pairIndex].averagePrice < allPairs[cheapestHourPairIndex!].averagePrice {
                        cheapestHourPairIndex = pairIndex
                    }
                } else {
                    cheapestHourPairIndex = pairIndex
                }
            }

            if cheapestHourPairIndex != nil {
                let cheapestPair = allPairs[cheapestHourPairIndex!]
                var maxPointIndex = cheapestPair.associatedPricePoints.count - 1
                
                let startTimeHourEnd = startTime.addingTimeInterval(3600)
                let endTimeHourStart = endTime.addingTimeInterval(-3600)
                let startDateFirstItem = Date(timeIntervalSince1970: TimeInterval(cheapestPair.associatedPricePoints[0].startTimestamp))
                let endDateLastItem = Date(timeIntervalSince1970: TimeInterval(cheapestPair.associatedPricePoints[maxPointIndex].endTimestamp))
                
                var intervenesWithStartHour = false
                if startDateFirstItem >= startTime && startDateFirstItem <= startTimeHourEnd {
                    intervenesWithStartHour = true
                }
                var intervenesWithEndHour = false
                if endDateLastItem >= endTimeHourStart && endDateLastItem <= endTime {
                    intervenesWithEndHour = true
                }
                
                func searchAndAddFollowingItem(timestamp: Int) {
                    // Find next following energy price point
                    for item in energyData.prices {
                        if item.startTimestamp == timestamp {
                            cheapestPair.associatedPricePoints.append(item)
                            print("Found the missing energy price point with start timestamp \(item.startTimestamp).")
                            break
                        }
                    }
                }
                
                if intervenesWithStartHour && !intervenesWithEndHour && startTimeDifference != 0 {
                    print("Intervenes with start hour")
                    searchAndAddFollowingItem(timestamp: Int(endDateLastItem.timeIntervalSince1970))
                    maxPointIndex = cheapestPair.associatedPricePoints.count - 1
                    
                    cheapestPair.associatedPricePoints[0].startTimestamp += startTimeDifference * 60
                    cheapestPair.associatedPricePoints[maxPointIndex].endTimestamp -= (60 - startTimeDifference) * 60
                }
                
                func searchAndAddPreFollowingItem(timestamp: Int) {
                    // Find the pre-following price point
                    for item in energyData.prices {
                        if item.endTimestamp == timestamp {
                            print("Found the missing energy proce point with end timestamp \(item.endTimestamp).")
                            cheapestPair.associatedPricePoints.insert(item, at: 0)
                            break
                        }
                    }
                }
                
                if intervenesWithEndHour && !intervenesWithStartHour && endTimeDifference != 0 {
                    print("Intervenes with end hour")
                    searchAndAddPreFollowingItem(timestamp: Int(startDateFirstItem.timeIntervalSince1970))
                    maxPointIndex = cheapestPair.associatedPricePoints.count - 1
                    
                    cheapestPair.associatedPricePoints[maxPointIndex].endTimestamp -= (60 - endTimeDifference) * 60
                    cheapestPair.associatedPricePoints[0].startTimestamp += endTimeDifference * 60
                }
                
                if intervenesWithStartHour && intervenesWithEndHour {
                    print("Intervenes with both start and end hour")
                    var allItems = [EnergyPricePoint]()
                    for item in energyData.prices {
                        let itemStartTime = Date(timeIntervalSince1970: TimeInterval(item.startTimestamp))
                        let itemEndTime = Date(timeIntervalSince1970: TimeInterval(item.endTimestamp))
                        if itemStartTime >= startTime && itemEndTime <= endTime {
                            allItems.append(item)
                        }
                    }
                    
                    
                    if (startTimeDifference != 0) || (endTimeDifference != 0) {
                        var returnModifiedAllItems = false
                        if allItems[0].startTimestamp == cheapestPair.associatedPricePoints[0].startTimestamp {
                            allItems[0].startTimestamp += startTimeDifference * 60
                            allItems[allItems.count - 1].endTimestamp -= (60 - startTimeDifference) * 60
                            returnModifiedAllItems = true
                            
                        } else if allItems[allItems.count - 1].endTimestamp == cheapestPair.associatedPricePoints[maxPointIndex].endTimestamp {
                            allItems[allItems.count - 1].endTimestamp -= (60 - endTimeDifference) * 60
                            allItems[0].startTimestamp += endTimeDifference * 60
                            returnModifiedAllItems = true
                        }
                        
                        if returnModifiedAllItems {
                            cheapestPair.associatedPricePoints = allItems
                        }
                    }
                }
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
