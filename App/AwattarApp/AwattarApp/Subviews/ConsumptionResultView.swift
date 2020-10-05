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
                Spacer()
                
                VStack(spacing: 5) {
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: startOfCheapestHours)))
                        .bold()
                        .onAppear {
                            startOfCheapestHours =  TimeInterval((cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp) + (cheapestHourCalculator.cheapestHoursForUsage!.differenceIsBefore ? cheapestHourCalculator.cheapestHoursForUsage!.minuteDifferenceInSeconds : 0))
                        }
                    
                    Text("until")
                    
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: endOfCheapestHours)))
                        .bold()
                        .onAppear {
                            endOfCheapestHours =  TimeInterval((cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints.count - 1].endTimestamp) + (cheapestHourCalculator.cheapestHoursForUsage!.differenceIsBefore ? cheapestHourCalculator.cheapestHoursForUsage!.minuteDifferenceInSeconds : 0))
                        }
                }
                .font(.title2)
                
                Spacer()
                
                VStack {
                    ConsumptionClockView(cheapestHour: cheapestHourCalculator.cheapestHoursForUsage!)
                        .frame(maxHeight: 200)
                }
                
                Spacer()
                Spacer()
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding(16)
        .animation(.easeInOut)
        .onAppear {
            cheapestHourCalculator.setValues()
            cheapestHourCalculator.calculateBestHours(energyData: awattarData.energyData!)
        }
        .navigationBarTitle("results")
    }
}
