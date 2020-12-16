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
    @EnvironmentObject var currentSetting: CurrentSetting
    
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
        VStack(alignment: .center, spacing: 0) {
            if cheapestHourManager.cheapestHoursForUsage != nil {
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
                .padding([.leading, .trailing], 16)
                
                Spacer()
                
                HStack {
                    Text("today")
                    Text(todayDateFormatter.string(from: Date()))
                        .bold()
                        .foregroundColor(Color.red)
                }
                .font(.callout)
                .padding([.leading, .trailing], 16)
                
                // The final price the user would need to pay
                if cheapestHourManager.cheapestHoursForUsage!.hourlyEnergyCosts != nil {
                    if let hourlyCostString = currencyFormatter.string(from: NSNumber(value: cheapestHourManager.cheapestHoursForUsage!.hourlyEnergyCosts!)) {
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 5) {
                            Text("elecCosts")
                            
                            Text(hourlyCostString)
                                .bold()
                                .font(.title3)
                            
                            if currentSetting.setting!.pricesWithTaxIncluded {
                                Text("priceWithVatNote")
                                    .font(.caption)
                            } else {
                                Text("priceWithoutVatNote")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(Color.white)
                        .shadow(radius: 4)
                        .padding(5)
                        .frame(maxWidth: .infinity)
                        .background(colorScheme == .light ? Color(hue: 0.3815, saturation: 0.6605, brightness: 0.8431) : Color(hue: 0.3844, saturation: 0.6293, brightness: 0.6288))
                    }
                }
                
                Spacer()
                // The clock which visually presents the results.
                HStack(spacing: 10) {
                    ConsumptionClockView(cheapestHourManager.cheapestHoursForUsage!)
                        .padding([.leading, .trailing], 20)
                        .frame(width: 330, height: 330)
                }
                .padding([.leading, .trailing], 16)
                
                Spacer()
                Spacer()
            } else if cheapestHourManager.errorOccurredFindingCheapestHours == true {
                Text("cheapestTimeErrorOccurred")
                    .multilineTextAlignment(.center)
                    .font(.callout)
            } else {
                // If calculations haven't finished yet display this progress view
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .onAppear {
            cheapestHourManager.calculateCheapestHours(energyData: awattarData.energyData!, currentSetting: currentSetting)
        }
        .onChange(of: currentSetting.setting!.awattarTariffIndex) { _ in
            // The tariff selection has affects on the hourly price which was calculated previously. That's why it has to be recalculated when the tariff selection changes.
            if cheapestHourManager.cheapestHoursForUsage != nil {
                cheapestHourManager.cheapestHoursForUsage!.calculateHourlyPrice(currentSetting: currentSetting)
            }
        }
        .onChange(of: currentSetting.setting!.awattarBaseElectricityPrice) { _ in
            if cheapestHourManager.cheapestHoursForUsage != nil {
                cheapestHourManager.cheapestHoursForUsage!.calculateHourlyPrice(currentSetting: currentSetting)
            }
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
