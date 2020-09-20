//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

class EnergyCalculator: ObservableObject {
    @Published var energyUsageInput = "20"
    
    @Published var startDate = Date()
    @Published var timeOfUsageTimeInterval = Date()
    
    @Published var energyUsage = Double(0) // energy usage in kW
    @Published var timeOfUsage = TimeInterval() // time interval in seconds
    
    @Published var cheapestHoursForUsage: HourPair? = nil
    
    init() {
        let calendar = Calendar(identifier: .gregorian)
        startDate = calendar.startOfDay(for: startDate)
        timeOfUsageTimeInterval = calendar.startOfDay(for: startDate)
    }
    
    func setValues() {
        self.energyUsage = Double(self.energyUsageInput) ?? 0
        self.timeOfUsage = abs(startDate.timeIntervalSince(timeOfUsageTimeInterval))
    }
    
    class HourPair {
        // A pair of multiple price points
        
        var averagePrice: Float = 0
        var associatedPricePoints: [EnergyPricePoint]
        
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
    }
    
    func calculateBestHours(energyData: EnergyData) {
        // Energy used in a certain time interval is specified by the user
        // This function than can calculate when the cheapest hours are for the users energy consumption
        // Example:
        // Want to charge EV for two hours. Function calculates for the user the cheapest hours to charge his EV.
        // Output would be for example from 4pm to 6pm.
        
        let timeOfUsageInHours: Int = Int(timeOfUsage / 60 / 60)

        var allPairs = [HourPair]()
        for hourIndex in 0..<energyData.prices.count {
            let newPairNode = HourPair(associatedPricePoints: [energyData.prices[hourIndex]])
            
            for nextHourIndex in 1..<timeOfUsageInHours {
                if (hourIndex + nextHourIndex) <= (energyData.prices.count - 1) {
                    newPairNode.associatedPricePoints.append(energyData.prices[hourIndex + nextHourIndex])
                }
            }

            newPairNode.calculateAveragePrice()
            allPairs.append(newPairNode)
        }
        
        var lowestPricePairIndex: Int? = nil
        for pairIndex in 0..<allPairs.count {
//            print("Number of elements: \(allPairs[pairIndex].associatedPricePoints.count)")
//            print("1: \(allPairs[pairIndex].associatedPricePoints[0].marketprice)")
//
//            if allPairs[pairIndex].associatedPricePoints.count >= 2 {
//                print("2: \(allPairs[pairIndex].associatedPricePoints[1].marketprice)")
//            }
//            if allPairs[pairIndex].associatedPricePoints.count >= 3 {
//                print("3: \(allPairs[pairIndex].associatedPricePoints[2].marketprice)")
//            }
//
//            if allPairs[pairIndex].associatedPricePoints.count >= 4 {
//                print("4: \(allPairs[pairIndex].associatedPricePoints[3].marketprice)")
//            }
//
//            print(allPairs[pairIndex].averagePrice)
            
            if lowestPricePairIndex != nil {
                if allPairs[pairIndex].averagePrice < allPairs[lowestPricePairIndex!].averagePrice {
                    lowestPricePairIndex = pairIndex
                }
            } else {
                lowestPricePairIndex = pairIndex
            }
        }
        
        if lowestPricePairIndex != nil {
            cheapestHoursForUsage = allPairs[lowestPricePairIndex!]
        }
    }
}

struct ConsumptionComparatorView: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    
    @ObservedObject var energyCalculator = EnergyCalculator()
    
    var dateFormatter: DateFormatter
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
    }
    
    var body: some View {
        VStack(alignment: .center) {
            if currentSetting.setting != nil && awattarData.energyData != nil {
                Text("Bestmögliche Zeit für Verbrauch finden")
                    .bold()
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Deine angegebene Grundgebühr: ")
                        Spacer()
                        HStack(spacing: 5) {
                            Text(String(currentSetting.setting!.awattarProfileBasicCharge))
                            Text("Cent pro kWh")
                        }
                    }
                    
                    HStack {
                        Text("Dein angegebener Strompreis: ")
                        Spacer()
                        HStack(spacing: 5) {
                            Text(String(currentSetting.setting!.awattarEnergyPrice))
                            Text("Cent pro kWh")
                        }
                    }
                    
                    TextField("Verbrauch", text: $energyCalculator.energyUsageInput)
                        .keyboardType(.decimalPad)
                    
                    if energyCalculator.cheapestHoursForUsage != nil {
                        ForEach(energyCalculator.cheapestHoursForUsage!.associatedPricePoints, id: \.self) { cheapestHour in
                            Text(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(cheapestHour.startTimestamp / 1000))))
                        }
                    }
                    
                    
                    TimeIntervalPicker(selectedInterval: $energyCalculator.timeOfUsageTimeInterval)
                        .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        energyCalculator.setValues()
                        energyCalculator.calculateBestHours(energyData: awattarData.energyData!.awattar)
                    }) {
                        Text("Berechnen")
                    }
                }
                
                Spacer()
            } else {
                Text("Fehler mit Einstellungen")
            }
        }
        .padding()
    }
}

struct ConsumptionComparatorView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionComparatorView()
            .environmentObject(CurrentSetting())
    }
}
