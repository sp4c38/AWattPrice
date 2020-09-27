//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import SwiftUI

struct ConsumptionResultView: View {
    @EnvironmentObject var awattarData: AwattarData
    
    var cheapestHourCalculator: CheapestHourCalculator
    var dateFormatter = DateFormatter()
    
    init(cheapestHourCalculator: CheapestHourCalculator) {
        self.cheapestHourCalculator = cheapestHourCalculator
  
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
    }
    
    var body: some View {
        VStack {
            if cheapestHourCalculator.cheapestHoursForUsage != nil {
                ConsumptionClockView(cheapestHour: cheapestHourCalculator.cheapestHoursForUsage!)
                    .frame(maxHeight: 200)
                
                ForEach(cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints, id: \.startTimestamp) { hour in
                    HStack {
                        Text(dateFormatter.string(from: Date(timeIntervalSince1970:  TimeInterval(hour.startTimestamp / 1000))))
                        Text("until")
                        Text(dateFormatter.string(from: Date(timeIntervalSince1970:  TimeInterval(hour.endTimestamp / 1000))))
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .animation(.easeInOut)
        .onAppear {
            cheapestHourCalculator.setValues()
            cheapestHourCalculator.calculateBestHours(energyData: awattarData.energyData!.awattar)
        }
    }
}
