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
    @State var cheapestTimeIntervalSince1970: TimeInterval = 0
    
    init(cheapestHourCalculator: CheapestHourCalculator) {
        self.cheapestHourCalculator = cheapestHourCalculator
  
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
    }
    
    var body: some View {
        VStack {
            if cheapestHourCalculator.cheapestHoursForUsage != nil {
                HStack {
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: cheapestTimeIntervalSince1970)))
                        .onAppear {
                            cheapestTimeIntervalSince1970 =  TimeInterval(cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints.count - 1].startTimestamp + (cheapestHourCalculator.cheapestHoursForUsage!.differenceIsBefore ? cheapestHourCalculator.cheapestHoursForUsage!.minuteDifferenceInSeconds : 0))
                        }
                    
                    Text("until")
                    
//                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:  TimeInterval(hour.endTimestamp / 1000))))
                }
                
                ConsumptionClockView(cheapestHour: cheapestHourCalculator.cheapestHoursForUsage!)
                    .frame(maxHeight: 200)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .animation(.easeInOut)
        .onAppear {
            cheapestHourCalculator.setValues()
            cheapestHourCalculator.calculateBestHours(energyData: awattarData.energyData!)
        }
    }
}
