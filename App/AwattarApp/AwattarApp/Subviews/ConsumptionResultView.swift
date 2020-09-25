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
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
    }
    
    var body: some View {
        VStack {
            if cheapestHourCalculator.cheapestHoursForUsage != nil {
                ForEach(cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints, id: \.self) { cheapestHour in
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(cheapestHour.startTimestamp / 1000))))
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
