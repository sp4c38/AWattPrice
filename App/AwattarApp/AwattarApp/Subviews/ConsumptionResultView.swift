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
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        VStack {
            if cheapestHourCalculator.cheapestHoursForUsage != nil {
                ConsumptionClockView(cheapestHour: cheapestHourCalculator.cheapestHoursForUsage!)
                
                ForEach(cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints, id: \.self) { cheapestHour in
                    HStack {
                        Text(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(cheapestHour.startTimestamp / 1000))))
                        Text("bis")
                        Text(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(cheapestHour.endTimestamp / 1000))))
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .onAppear {
            cheapestHourCalculator.setValues()
            cheapestHourCalculator.calculateBestHours(energyData: awattarData.energyData!.awattar)
        }
    }
}
