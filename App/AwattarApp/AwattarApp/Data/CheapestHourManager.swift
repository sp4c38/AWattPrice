//
//  CheapestHourManager.swift
//  AwattarApp
//
//  Created by Léon Becker on 22.10.20.
//

import Foundation

/// An object which manages the calculation of when the cheapest hours are for energy consumption
class CheapestHourManager: ObservableObject {
    @Published var powerOutputString = ""
    @Published var powerOutput: Double = 0
    
    @Published var energyUsageString = ""
    @Published var energyUsage: Double = 0
    
    // Time range from startDate to endDate in which to find the cheapest hours
    @Published var startDate = Date()
    @Published var endDate = Date().addingTimeInterval(3600)
    
    // This value won't be changed. Its purpose is to serve as a reference point to dermiter the time range set in the time interval picker (lengthOfUsageDate).
//    var relativeLengthOfUsageDate = Date(timeIntervalSince1970: 82800)
    // A time selected with a time interval picker. It serves as second point to dermiter the time range for how long the electrical consumer shall operate.
//    @Published var lengthOfUsageDate = Date(timeIntervalSince1970: 83100)
    
    @Published var timeOfUsage: Double = 0
    
    /// The results of the calculation of the cheapest hours for usage which are represented in an HourPair object.
    @Published var cheapestHoursForUsage: HourPair? = nil
    /// A variable set to true if calculations have been performed but no cheapest hours were found.
    @Published var errorOccurredFindingCheapestHours = false
    
    /// Checks that the interval selected by the Interval Picker is not bigger than the time range between the start date and end date specified by the user. If the interval is bigger than the end date is adjusted accordingly.
    func checkIntervalFitsInRange() {
//        let startEndDateInterval = abs(startDate.timeIntervalSince(endDate))
//        let timeOfUsageInterval = abs(relativeLengthOfUsageDate.timeIntervalSince(lengthOfUsageDate))
//
//        if startEndDateInterval < timeOfUsageInterval {
//            endDate.addTimeInterval(timeOfUsageInterval - startEndDateInterval)
//        }
    }
    
    /// Sets the values after the user entered them. This includes calculating time intervals and formatting raw text strings to floats. If errors occur because of wrong input of the user and values cannot be set correctly a list is returned with error values.
    /// - Returns: Returns a list with error values if any occur. If no errors occur a list is also returned but with a success value
    ///     - [0] all values were entered correctly
    ///     - [1] powerOutputString is empty
    ///     - [2] powerOutputString contains wrong characters
    ///     - [3] energyUsageString is empty
    ///     - [4] energyUsageString contains wrong characters
    
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
            errorValues.append(0)
            
            self.timeOfUsage = self.energyUsage / self.powerOutput
        }
        
        return errorValues
    }
    
    /// A pair of one, two, three or more EnergyPricePoints. This object supports functionallity to calculate the average price or to sort the associated price points for day.
    class HourPair {
        var averagePrice: Float = 0
        var associatedPricePoints: [EnergyPricePoint]
//        var associatedPricePointsSorted = [[EnergyPricePoint]]()
        /// Final energy cost which is calculated with a certain power (kW) a electrical consumer uses and the time of the usage.
        var energyCosts: Float? = nil
        
        init(associatedPricePoints: [EnergyPricePoint]) {
            self.associatedPricePoints = associatedPricePoints
        }
        
        /// Caluclates the average price from the energy price of all to this HourPair associated price points.
        func calculateAveragePrice() {
            var pricesTogether: Float = 0
            for pricePoint in self.associatedPricePoints {
                pricesTogether += pricePoint.marketprice
            }
            self.averagePrice = pricesTogether / Float(associatedPricePoints.count)
        }
        
//        func sortAssociatedPricePoints() {
//            var indexCounter = -1
//            var currentNextMidnight: Date? = nil
//
//            for pricePoint in self.associatedPricePoints {
//                let pricePointStartDate = Date(timeIntervalSince1970: TimeInterval(pricePoint.startTimestamp))
//
//                if currentNextMidnight == nil || pricePointStartDate >= currentNextMidnight! {
//                    currentNextMidnight = Calendar.current.startOfDay(for: pricePointStartDate.addingTimeInterval(86400))
//                    indexCounter += 1
//                }
//
//                if pricePointStartDate < currentNextMidnight! {
//                    if indexCounter > (self.associatedPricePointsSorted.count - 1) {
//                        associatedPricePointsSorted.append([pricePoint])
//                    } else {
//                        self.associatedPricePointsSorted[indexCounter].append(pricePoint)
//                    }
//                }
//            }
//        }
    }
    
    /**
     Function to calculate when energy prices are cheapest.
     - Returns: Doesn't return value directly. Instead sets cheapestHoursForUsage of CheapestHourManager to the result HourPair.
     - Parameter energyData: Current energy data (data downloaded from the server)
     */
    func calculateCheapestHours(energyData: EnergyData) {
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
            let now = Date()
            
            let nextRoundedUpHour = Int(self.timeOfUsage.rounded(.up))

            // Create all HourPair's for later comparison
            var allPairs = [HourPair]()
            for hourIndex in 0..<energyData.prices.count {
                if hourIndex + (nextRoundedUpHour - 1) <= energyData.prices.count - 1 {
                    let hourStartDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[hourIndex].startTimestamp))
                    
                    let maxHourThisPairEndDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[hourIndex + (nextRoundedUpHour - 1)].endTimestamp))
                    
                    if hourStartDate >= now && hourStartDate >= self.startDate && maxHourThisPairEndDate <= self.endDate {
                        let newPairNode = HourPair(associatedPricePoints: [energyData.prices[hourIndex]])
                        
                        for nextHourIndex in 1..<nextRoundedUpHour {
                            if (hourIndex + nextHourIndex) <= (energyData.prices.count - 1) {
                                newPairNode.associatedPricePoints.append(energyData.prices[hourIndex + nextHourIndex])
                            } else {
                                break
                            }
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
            
            let minuteDifferenceInSeconds = Int(((Double(nextRoundedUpHour) - self.timeOfUsage) * 60 * 60).rounded())
            var differenceIsBefore = false
            
            if cheapestHourPairIndex != nil {
                // A index was found for the cheapest HourPair
                
                let cheapestPair = allPairs[cheapestHourPairIndex!]
                let maxAssociatedPricePointsIndex = cheapestPair.associatedPricePoints.count - 1

                if cheapestPair.associatedPricePoints[0].marketprice > cheapestPair.associatedPricePoints[maxAssociatedPricePointsIndex].marketprice {
                    differenceIsBefore = true
                }

                if differenceIsBefore {
                    cheapestPair.associatedPricePoints[0].startTimestamp += minuteDifferenceInSeconds
                } else {
                    cheapestPair.associatedPricePoints[maxAssociatedPricePointsIndex].endTimestamp -= minuteDifferenceInSeconds
                }
            }
            
            DispatchQueue.main.async {
                if cheapestHourPairIndex != nil {
                    self.cheapestHoursForUsage = allPairs[cheapestHourPairIndex!]
                    self.errorOccurredFindingCheapestHours = true
                }
            }
        }
    }
}
