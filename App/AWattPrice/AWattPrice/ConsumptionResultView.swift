//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import SwiftUI

/// A view which presents the results calculated by the CheapestHourManager of when the cheapest hours for the usage of energy are.
struct ConsumptionResultView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    var dateFormatter: DateFormatter
    var todayDateFormatter: DateFormatter
    let currencyFormatter: NumberFormatter
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        todayDateFormatter = DateFormatter()
        todayDateFormatter.dateStyle = .long
        todayDateFormatter.timeStyle = .none
        
        currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.locale = Locale(identifier: "de_DE")
        currencyFormatter.currencySymbol = "ct"
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.minimumFractionDigits = 2
    }
    
    var body: some View {
        VStack(alignment: .center) {
            if cheapestHourManager.cheapestHoursForUsage != nil {
                Spacer()
                
                // The time range in which the cheapest hours are
                VStack(alignment: .center, spacing: 5) {
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:
                                                            TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp))))
                        .bold()

                    Text("until")

                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:
                                                            TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.count - 1].endTimestamp))))
                        .bold()
                }
                .font(.title2)
                .padding(16)
                
                HStack {
                    Text("today")
                    Text(todayDateFormatter.string(from: Date()))
                        .bold()
                        .foregroundColor(Color.red)
                }
                .font(.callout)
                .padding(16)
                
                // The final price the user would need to pay
                if cheapestHourManager.cheapestHoursForUsage!.energyCosts != nil {
                    VStack(alignment: .center, spacing: 5) {
                        Text("elecCosts")
                        
                        Text(currencyFormatter.string(from: NSNumber(value: (cheapestHourManager.cheapestHoursForUsage!.energyCosts!))) ?? "") // Convert to Euro
                            .font(.headline)
                    }
                    .foregroundColor(Color.white)
                    .shadow(radius: 4)
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(colorScheme == .light ? Color(hue: 0.3815, saturation: 0.6605, brightness: 0.8431) : Color(hue: 0.3844, saturation: 0.6293, brightness: 0.6288))
                    .padding(.top, 5)
                }
                
                // The clock which visually presents the results.
                HStack(spacing: 10) {
                    ConsumptionClockView(cheapestHourManager.cheapestHoursForUsage!)
                        .padding([.leading, .trailing], 20)
                }
                .padding(16)
            } else if cheapestHourManager.errorOccurredFindingCheapestHours == true {
                Text("An error occurred.\nPlease try again later.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
            } else {
                // If calculations haven't finished yet display this progress view
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .onAppear {
            cheapestHourManager.calculateCheapestHours(energyData: awattarData.energyData!)
        }
        .navigationTitle("result")
    }
}

struct ConsumptionResultView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionResultView()
            .environmentObject(AwattarData())
            .environmentObject(CheapestHourManager())
            .preferredColorScheme(.light)
    }
}
