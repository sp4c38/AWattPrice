//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

class CheapestHourCalculator: ObservableObject {
    @Published var energyUsageInput = "20"
    
    @Published var startDate = Date(timeIntervalSince1970: 0)
    @Published var endDate = Date(timeIntervalSince1970: 5400)
    
    @Published var energyUsage = Double(0) // energy usage in kW
    @Published var timeOfUsage = TimeInterval() // time interval in seconds
    
    @Published var cheapestHoursForUsage: HourPair? = nil
    
    init() {
        let calendar = Calendar(identifier: .gregorian)
        startDate = calendar.startOfDay(for: startDate)
        endDate = calendar.startOfDay(for: startDate)
    }
    
    func setValues() {
        self.energyUsage = Double(self.energyUsageInput) ?? 0
        self.timeOfUsage = abs(startDate.timeIntervalSince(endDate))
    }
    
    class HourPair {
        // A pair of multiple price points
        
        var minuteDifferenceInSeconds: Int = 0
        var differenceIsBefore: Bool = true
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
        // This function than can calculate when the cheapest hours are for the energy consumption
        // Example:
        // Want to charge EV for two hours. Function calculates for the user the cheapest hours to charge his EV.
        // Output would be for example from 4pm to 6pm.
        
        DispatchQueue.global(qos: .userInitiated).async {
            let timeOfUsageInHours: Float = Float(self.timeOfUsage / 60 / 60)
            let nextRoundedUpHour = Int(timeOfUsageInHours.rounded(.up))

            var allPairs = [HourPair]()
            for hourIndex in 0..<energyData.prices.count {
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
            
            let minuteDifferenceInSeconds = Int(((Float(nextRoundedUpHour) - timeOfUsageInHours) * 60 * 60 ).rounded())
            var differenceIsBefore = false
            
            if lowestPricePairIndex != nil {
                let cheapestPair = allPairs[lowestPricePairIndex!]

                if cheapestPair.associatedPricePoints[0].marketprice > cheapestPair.associatedPricePoints[cheapestPair.associatedPricePoints.count - 1].marketprice {
                    differenceIsBefore = true
                }
                
                cheapestPair.minuteDifferenceInSeconds = minuteDifferenceInSeconds
                cheapestPair.differenceIsBefore = differenceIsBefore
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
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    
    @ObservedObject var cheapestHourCalculator = CheapestHourCalculator()
    
    @State var showInfo = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: Alignment(horizontal: .center, vertical: .top)) {
                VStack(alignment: .center, spacing: 0) {
                    if currentSetting.setting != nil && awattarData.energyData != nil {
                        VStack(alignment: .leading, spacing: 15) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Deine angegebene Grundgebühr: ")
                                    .bold()
                                
                                HStack(spacing: 5) {
                                    Text(String(currentSetting.setting!.awattarProfileBasicCharge))
                                    Text("Euro pro Monat")
                                }
                                .font(.callout)
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Dein angegebener Strompreis: ")
                                    .bold()
                                
                                HStack(spacing: 5) {
                                    Text(String(currentSetting.setting!.awattarEnergyPrice))
                                    Text("Cent pro kWh")
                                }
                                .font(.callout)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Stromverbrauch: ")
                                    .bold()
                                
                                HStack(spacing: 7) {
                                    TextField("Verbrauch", text: $cheapestHourCalculator.energyUsageInput)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.leading)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Text("kWh")
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Dauer des Verbrauches: ")
                                    .bold()
                                
                                TimeIntervalPicker(selectedInterval: $cheapestHourCalculator.endDate)
                                    .frame(maxWidth: .infinity)
                            }
                            
                            Button(action: {}) {
                                NavigationLink(destination: ConsumptionResultView(cheapestHourCalculator: cheapestHourCalculator)) {
                                    Text("Berechnen")
                                }
                            }.buttonStyle(DoneButtonStyle())
                        }
                    } else {
                        Text("Fehler mit Einstellungen")
                    }
                }
                .padding()
                .opacity(showInfo ? 0.5 : 1)
                
                if showInfo {
                    Text("Hiermit kannst du die Stunden finden, in denen der Strom preislich am günstigsten ist, um zum Beispiel dein Elektroauto aufzuladen, die Waschmachine einzuschalten oder andere elektrische Verbraucher laufen zu lassen.")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 20)
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
            .navigationBarTitle("Verbrauch")
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
