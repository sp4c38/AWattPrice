//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

class EnergyCalculator: ObservableObject {
    @Published var energyUsageInput = "20"
    @Published var timeOfUsageStartInput = Date(timeIntervalSince1970: 1600585200)
    @Published var timeOfUsageEndInput = Date(timeIntervalSince1970: 1600596000)
    
    @Published var energyUsage = Double(0) // energy usage in kW
    @Published var timeOfUsage = TimeInterval() // time interval in seconds
    @Published var powerUsage: Double? = nil // total power usage in kWh
    
    func setValues() {
        self.energyUsage = Double(self.energyUsageInput) ?? 0
        self.timeOfUsage = timeOfUsageEndInput.timeIntervalSince(timeOfUsageStartInput)
    }
    
    func calculateBestHours(energyData: EnergyData) {
        // Calculates which hours are best for energy consumption when using [energyUsage] for [timeOfUsage]
        class PairNode {
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
        
        let timeOfUsageInHours: Int = Int(timeOfUsage / 60 / 60)

        var allPairs = [PairNode]()
        for hourIndex in 0..<energyData.prices.count {
            let newPairNode = PairNode(associatedPricePoints: [energyData.prices[hourIndex]])
            
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
        
        for node in allPairs[lowestPricePairIndex!].associatedPricePoints {
            print("Charge in hour with price \(node.marketprice * 100 * 0.001)")
        }
    }
}

struct ConsumptionComparatorView: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    
    @ObservedObject var energyCalculator = EnergyCalculator()
    
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
                    
                    DatePicker("Start des Verbrauches", selection: $energyCalculator.timeOfUsageStartInput, displayedComponents: .hourAndMinute)
                        .datePickerStyle(DefaultDatePickerStyle())
                    
                    DatePicker("Ende des Verbrauches", selection: $energyCalculator.timeOfUsageEndInput, displayedComponents: .hourAndMinute)
                        .datePickerStyle(DefaultDatePickerStyle())
                    
                    Button(action: {
                        energyCalculator.setValues()
                        energyCalculator.calculateBestHours(energyData: awattarData.energyData!.awattar)
                    }) {
                        Text("Berechnen")
                    }
                    
                    Text("Bei einer Leistung von \(energyCalculator.energyUsageInput) für \(energyCalculator.timeOfUsage) verbrauchst du \(energyCalculator.powerUsage ?? 0)")
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
