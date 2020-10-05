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
    @State var startOfCheapestHours: TimeInterval = 0
    @State var endOfCheapestHours: TimeInterval = 0
    
    init(cheapestHourCalculator: CheapestHourCalculator) {
        self.cheapestHourCalculator = cheapestHourCalculator
  
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        VStack {
            if cheapestHourCalculator.cheapestHoursForUsage != nil {
                HStack(spacing: 20) {
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: startOfCheapestHours)))
                        .bold()
                        .onAppear {
                            startOfCheapestHours =  TimeInterval((cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp / 1000) + (cheapestHourCalculator.cheapestHoursForUsage!.differenceIsBefore ? cheapestHourCalculator.cheapestHoursForUsage!.minuteDifferenceInSeconds : 0))
                        }
                    
                    Text("until")
                    
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: endOfCheapestHours)))
                        .bold()
                        .onAppear {
                            endOfCheapestHours =  TimeInterval((cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints.count - 1].endTimestamp / 1000) + (cheapestHourCalculator.cheapestHoursForUsage!.differenceIsBefore ? cheapestHourCalculator.cheapestHoursForUsage!.minuteDifferenceInSeconds : 0))
                        }
                }
                .font(.title)
                
                Spacer()
                
                ConsumptionClockView(cheapestHour: cheapestHourCalculator.cheapestHoursForUsage!)
                    .frame(maxHeight: 200)
                
                Spacer()
                Spacer()
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
