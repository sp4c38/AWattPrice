//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import SwiftUI

struct ConsumptionResultView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var awattarData: AwattarData
    
    var cheapestHourCalculator: CheapestHourCalculator
    var dateFormatter: DateFormatter
    let currencyFormatter: NumberFormatter
    
    init(cheapestHourCalculator: CheapestHourCalculator) {
        self.cheapestHourCalculator = cheapestHourCalculator
  
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.locale = Locale(identifier: "de_DE")
        currencyFormatter.currencySymbol = "ct"
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.minimumFractionDigits = 2
    }
    
    var body: some View {
        VStack(alignment: .center) {
            if cheapestHourCalculator.cheapestHoursForUsage != nil {
                Spacer()
                
                VStack(alignment: .center, spacing: 5) {
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:
                                                            TimeInterval(cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp))))
                        .bold()

                    Text("until")

                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:
                                                            TimeInterval(cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints[cheapestHourCalculator.cheapestHoursForUsage!.associatedPricePoints.count - 1].endTimestamp))))
                        .bold()
                }
                .font(.title2)
                .padding(16)
                
                if cheapestHourCalculator.cheapestHoursForUsage!.energyCosts != nil {
                    VStack(alignment: .center, spacing: 5) {
                        Text("Insgesamter letztendlicher Preis:")
                        
                        Text(currencyFormatter.string(from: NSNumber(value: (cheapestHourCalculator.cheapestHoursForUsage!.energyCosts!))) ?? "") // Convert to Euro
                            .font(.headline)
                    }
                    .foregroundColor(Color.white)
                    .shadow(radius: 4)
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(colorScheme == .light ? Color(hue: 0.3815, saturation: 0.6605, brightness: 0.8431) : Color(hue: 0.3844, saturation: 0.6293, brightness: 0.6288))
                    .padding(.top, 5)
                }
                
                HStack(spacing: 10) {
                    ConsumptionClockView(cheapestHourCalculator.cheapestHoursForUsage!)
                        .padding([.leading, .trailing], 20)
                }
                .padding(16)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .onAppear {
            cheapestHourCalculator.setValues()
            cheapestHourCalculator.calculateBestHours(energyData: awattarData.energyData!)
        }
        .navigationBarTitle("results")
    }
}
