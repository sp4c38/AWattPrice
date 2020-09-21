//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import SwiftUI

struct ConsumptionResultView: View {
    @EnvironmentObject var awattarData: AwattarData
    
    var energyCalculator: EnergyCalculator
    var dateFormatter = DateFormatter()
    
    init(energyCalculator: EnergyCalculator) {
        self.energyCalculator = energyCalculator
        
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
    }
    
    var body: some View {
        VStack {
            if energyCalculator.cheapestHoursForUsage != nil {
                ForEach(energyCalculator.cheapestHoursForUsage!.associatedPricePoints, id: \.self) { cheapestHour in
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(cheapestHour.startTimestamp / 1000))))
                }
            } else {
                Text("Fehler aufgetreten.")
            }
        }
        .onAppear {
            energyCalculator.setValues()
            energyCalculator.calculateBestHours(energyData: awattarData.energyData!.awattar)
        }
    }
}
