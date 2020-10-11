//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

class CheapestHourCalculator: ObservableObject {
    @Published var energyUsageInput = "20"
    
    @Published var startDate = Date() // start date of in which time interval to find cheapest hours
    @Published var endDate = Date() // end date of in which time interval to find cheapest hours
    @Published var relativeLengthOfUsage = Date(timeIntervalSince1970: 82800)
    @Published var lengthOfUsageDate = Date(timeIntervalSince1970: 82800) // length of the usage / this date is relative to relativeLengthOfUsage to dermiter the time interval
    
    @Published var energyUsage = Double(0) // energy usage in kW
    @Published var timeOfUsage = TimeInterval() // time interval in seconds
    
    @Published var cheapestHoursForUsage: HourPair? = nil
    
    func setValues() {
        self.energyUsage = Double(self.energyUsageInput) ?? 0
        self.timeOfUsage = abs(relativeLengthOfUsage.timeIntervalSince(lengthOfUsageDate))
    }
    
    class HourPair {
        // A pair of multiple price points
        
        var averagePrice: Float = 0
        var associatedPricePoints: [EnergyPricePoint] // Price points associated with this hour pair
        var associatedPricePointsSorted = [[EnergyPricePoint]]()
        
        init(associatedPricePoints: [EnergyPricePoint]) {
            self.associatedPricePoints = associatedPricePoints
        }
        
        func calculateAveragePrice() {
            var pricesTogether: Float = 0
            for pricePoint in self.associatedPricePoints {
                pricesTogether += pricePoint.marketprice
            }
            self.averagePrice = pricesTogether / Float(associatedPricePoints.count)
        }
        
        func sortAssociatedPricePoints() {
            var indexCounter = -1
            var currentNextMidnight: Date? = nil
            
            for pricePoint in self.associatedPricePoints {
                let pricePointStartDate = Date(timeIntervalSince1970: TimeInterval(pricePoint.startTimestamp))
                
                if currentNextMidnight == nil || pricePointStartDate >= currentNextMidnight! {
                    currentNextMidnight = Calendar.current.startOfDay(for: pricePointStartDate.addingTimeInterval(86400))
                    indexCounter += 1
                }
                
                if pricePointStartDate < currentNextMidnight! {
                    if indexCounter > (self.associatedPricePointsSorted.count - 1) {
                        associatedPricePointsSorted.append([pricePoint])
                    } else {
                        self.associatedPricePointsSorted[indexCounter].append(pricePoint)
                    }
                }
            }
        }
    }
    
    func calculateBestHours(energyData: EnergyData) {
        // Energy used in a certain time interval is specified by the user
        // This function than can calculate when the cheapest hours are for the energy consumption
        // Example:
        // Want to charge EV for two hours. Function calculates for the user the cheapest hours to charge his EV.
        // Output would be for example from 4pm to 6pm.
        
        DispatchQueue.global(qos: .userInitiated).async {
            let now = Date() // Used to not output values before now
            let timeOfUsageInHours: Float = Float(self.timeOfUsage / 60 / 60)
            let nextRoundedUpHour = Int(timeOfUsageInHours.rounded(.up))

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
                        newPairNode.sortAssociatedPricePoints()
                        allPairs.append(newPairNode)
                    }
                }
            }
            
            
            var lowestPricePairIndex: Int? = nil
            for pairIndex in 0..<allPairs.count {
                if lowestPricePairIndex != nil {
                    if allPairs[pairIndex].averagePrice < allPairs[lowestPricePairIndex!].averagePrice {
                        lowestPricePairIndex = pairIndex
                    }
                } else {
                    lowestPricePairIndex = pairIndex
                }
            }
            
            let minuteDifferenceInSeconds = Int(((Float(nextRoundedUpHour) - timeOfUsageInHours) * 60 * 60).rounded())
            var differenceIsBefore = false
            
            if lowestPricePairIndex != nil {
                let cheapestPair = allPairs[lowestPricePairIndex!]
                let maxPricePointsIndex = cheapestPair.associatedPricePoints.count - 1

                if cheapestPair.associatedPricePoints[0].marketprice > cheapestPair.associatedPricePoints[maxPricePointsIndex].marketprice {
                    differenceIsBefore = true
                }

                if differenceIsBefore {
                    cheapestPair.associatedPricePoints[0].startTimestamp += minuteDifferenceInSeconds
                } else {
                    cheapestPair.associatedPricePoints[maxPricePointsIndex].endTimestamp -= minuteDifferenceInSeconds
                }
            }
            
            DispatchQueue.main.async {
                if lowestPricePairIndex != nil {
                    self.cheapestHoursForUsage = allPairs[lowestPricePairIndex!]
                }
            }
        }
    }
}

extension AnyTransition {
    static var scaledOpacity: AnyTransition {
        let insertion = AnyTransition.scale(scale: 2).combined(with: .opacity)
        let removal = AnyTransition.scale(scale: 2).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

struct ConsumptionComparisonView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    
    @ObservedObject var cheapestHourCalculator = CheapestHourCalculator()
    
    @State var showInfo = false
    
    @State var calculateAction: Int? = 0 // Takes care of navigating to the result view
    
    
    var dateClosedRange: ClosedRange<Date> {
        let maxHourIndex = awattarData.energyData!.prices.count - 1
        
        // Add one or subtract one to not overlap to the next or previouse day
        let min = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[0].startTimestamp + 1))
        let max = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[maxHourIndex].endTimestamp - 1))
        
        return min...max
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: Alignment(horizontal: .center, vertical: .top)) {
                ScrollView {
                    VStack(alignment: .center, spacing: 0) {
                        if currentSetting.setting != nil && awattarData.energyData != nil {
                            VStack(alignment: .leading, spacing: 15) {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("elecUsage")
                                        .bold()
                                    
                                    HStack(spacing: 7) {
                                        TextField("elecUsage", text: $cheapestHourCalculator.energyUsageInput)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.leading)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        
                                        Text("kWh")
                                    }
                                }
//
                                VStack {
                                    DatePicker(
                                        selection: $cheapestHourCalculator.startDate,
                                        in: dateClosedRange,
                                        displayedComponents: [.date, .hourAndMinute],
                                        label: { Text("startOfUse").bold() })
                                    
                                    DatePicker(
                                        selection: $cheapestHourCalculator.endDate,
                                        in: dateClosedRange,
                                        displayedComponents: [.date, .hourAndMinute],
                                        label: { Text("endOfUse").bold() })
                                }
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("lengthOfUse")
                                        .bold()

                                    TimeIntervalPicker(selectedInterval: $cheapestHourCalculator.lengthOfUsageDate)
                                        .frame(maxWidth: .infinity)
                                }
                                
                                NavigationLink(destination: ConsumptionResultView(cheapestHourCalculator: cheapestHourCalculator), tag: 1, selection: $calculateAction) {
                                }
                                
                                Button(action: {
                                    calculateAction = 1
                                }) {
                                    Text("viewResults")
                                }.buttonStyle(DoneButtonStyle())
                            }
                        } else {
                            Text("Fehler mit Einstellungen")
                        }
                    }
                    .padding()
                    .opacity(showInfo ? 0.5 : 1)
                }
                
                if showInfo {
                    Text("comparerInfoText")
                        .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                        .padding()
                        .background(colorScheme == .light ? Color.white : Color(hue: 0.5417, saturation: 0.0930, brightness: 0.1686))
                        .cornerRadius(10)
                        .shadow(radius: 20)
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                        .transition(.scaledOpacity)
                }
            }
            .onTapGesture {
                if showInfo {
                    withAnimation {
                        showInfo = false
                    }
                }
            }
            .navigationBarTitle("usage")
            .navigationBarItems(trailing:
                Button(action: {
                    withAnimation {
                        showInfo.toggle()
                    }
                }) {
                    Image(systemName: "info.circle")
                        .frame(width: 20, height: 20)
                }
            )
        }
    }
}

struct ConsumptionComparatorView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionComparisonView()
            .environmentObject(CurrentSetting())
    }
}
