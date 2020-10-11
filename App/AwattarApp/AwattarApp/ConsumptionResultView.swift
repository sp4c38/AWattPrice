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
                Spacer()
                
                VStack(spacing: 5) {
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:
                                                            TimeInterval(cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp))))
                        .bold()

                    Text("until")

                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:
                                                            TimeInterval(cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints.count - 1].endTimestamp))))
                        .bold()
                }
                .font(.title2)
                
                Spacer()
                
                HStack(spacing: 10) {
                    ConsumptionClockView(cheapestHourCalculator.cheapestHoursForUsage!)
                        .padding(20)
                }
                
                Spacer()
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding(16)
        .onAppear {
            cheapestHourCalculator.setValues()
            cheapestHourCalculator.calculateBestHours(energyData: awattarData.energyData!)
        }
        .navigationBarTitle("results")
    }
}
