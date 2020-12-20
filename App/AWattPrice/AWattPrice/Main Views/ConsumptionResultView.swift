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
    
    func getTotalTime() -> String {
        let firstItemStart = Date(timeIntervalSince1970: TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp))
        let maxPointIndex = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.count - 1
        let lastItemEnd = Date(timeIntervalSince1970: TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[maxPointIndex].endTimestamp))
        let interval = lastItemEnd.timeIntervalSince(firstItemStart) / 60 / 60

        let hours = interval.rounded(.down)
        let minutes = 60 * (interval - hours)
        return TotalTimeFormatter().localizedTotalTimeString(hour: hours, minute: minutes)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if cheapestHourManager.cheapestHoursForUsage != nil {
                // The time range in which the cheapest hours are
                Spacer(minLength: 0)
                
                VStack(alignment: .center, spacing: 5) {
                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:
                                                            TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp))))
                        .bold()
                        .font(.title2)

                    Text("general.until")
                        .font(.title2)

                    Text(dateFormatter.string(from: Date(timeIntervalSince1970:
                                                            TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.count - 1].endTimestamp))))
                        .bold()
                        .font(.title2)
                }
                .padding(.bottom, 25)
                
                HStack(alignment: .center) {
                    Text("cheapestPriceResultPage.totalTime")
                    Text(getTotalTime())
                        .bold()
                }
                .padding(.bottom, 25)

                HStack(alignment: .center) {
                    Text("general.today")
                    Text(todayDateFormatter.string(from: Date()))
                        .bold()
                        .foregroundColor(Color.red)
                }
                .font(.callout)
                
                Spacer(minLength: 0)
                
                // The final price the user would need to pay
//                if cheapestHourManager.cheapestHoursForUsage!.hourlyEnergyCosts != nil {
//                    if let hourlyCostString = currencyFormatter.string(from: NSNumber(value: cheapestHourManager.cheapestHoursForUsage!.hourlyEnergyCosts!)) {
//                        Spacer()
//
//                        VStack(alignment: .center, spacing: 5) {
//                            Text("cheapestPriceResultPage.elecCosts")
//
//                            Text(hourlyCostString)
//                                .bold()
//                                .font(.title3)
//
//                            if currentSetting.setting!.pricesWithTaxIncluded {
//                                Text("cheapestPriceResultPage.priceWithVatNote")
//                                    .font(.caption)
//                            } else {
//                                Text("cheapestPriceResultPage.priceWithoutVatNote")
//                                    .font(.caption)
//                            }
//                        }
//                        .foregroundColor(Color.white)
//                        .shadow(radius: 4)
//                        .padding(5)
//                        .frame(maxWidth: .infinity)
//                        .background(colorScheme == .light ? Color(hue: 0.3815, saturation: 0.6605, brightness: 0.8431) : Color(hue: 0.3844, saturation: 0.6293, brightness: 0.6288))
//                    }
//                }
                
                // The clock which visually presents the results.
                HStack(spacing: 10) {
                    ConsumptionClockView(cheapestHourManager.cheapestHoursForUsage!)
                        .padding([.leading, .trailing], 20)
                        .frame(width: 310, height: 310)
                }

                Spacer(minLength: 0)
            } else if cheapestHourManager.errorOccurredFindingCheapestHours == true {
                Text("cheapestPriceResultPage.cheapestTimeErrorOccurred")
                    .multilineTextAlignment(.center)
                    .font(.callout)
            } else {
                // If calculations haven't finished yet display this progress view
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding([.leading, .trailing], 16)
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
        .navigationTitle("general.result")
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