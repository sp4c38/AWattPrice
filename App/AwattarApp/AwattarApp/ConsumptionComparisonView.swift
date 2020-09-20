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
    
    @ObservedObject var energyCalculator = EnergyCalculator()
    
    @State var showInfo = false
    
    var dateFormatter: DateFormatter
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
    }
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .top)) {
            VStack(alignment: .center, spacing: 0) {
                if currentSetting.setting != nil && awattarData.energyData != nil {
                    HStack {
                        Button(action: {
                            withAnimation {
                                showInfo.toggle()
                            }
                        }) {
                            Image(systemName: "info.circle")
                                .frame(width: 20, height: 20)
                        }
                        
                        Spacer()
                    }
                    
                    Text("Bestmögliche Zeit für Verbrauch finden")
                        .bold()
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 30)
                    
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
                                TextField("Verbrauch", text: $energyCalculator.energyUsageInput)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Text("kWh")
                            }
                        }
                        
                        if energyCalculator.cheapestHoursForUsage != nil {
                            ForEach(energyCalculator.cheapestHoursForUsage!.associatedPricePoints, id: \.self) { cheapestHour in
                                Text(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(cheapestHour.startTimestamp / 1000))))
                            }
                        }
                        
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Dauer des Verbrauches: ")
                                .bold()
                            
                            TimeIntervalPicker(selectedInterval: $energyCalculator.timeOfUsageTimeInterval)
                                .frame(maxWidth: .infinity)
                        }
                        
                        Button(action: {
                            energyCalculator.setValues()
                            energyCalculator.calculateBestHours(energyData: awattarData.energyData!.awattar)
                        }) {
                            Text("Berechnen")
                        }
                        .buttonStyle(DoneButtonStyle())
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
                    .padding(.top, 60)
            }
        }
        .onTapGesture {
            if showInfo {
                withAnimation {
                    showInfo = false
                }
            }
        }
    }
}

struct ConsumptionComparatorView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionComparisonView()
            .environmentObject(CurrentSetting())
    }
}
