//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import SwiftUI

struct CheapestTimeResultTimeRange: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    var dateFormatter: DateFormatter
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
    }

    func getDateString(start: Bool, end: Bool) -> String {
        if !(start == false && end == false) && !(start == true && end == true) {
            var timeInterval = TimeInterval(0)
            if start == true {
                timeInterval = TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp)
            } else if end == true {
                let maxItem = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.endIndex - 1
                timeInterval = TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[maxItem].endTimestamp)
            }
            let startDate = Date(timeIntervalSince1970: timeInterval)
            return dateFormatter.string(from: startDate)
        } else {
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            Text(getDateString(start: true, end: false))
                .bold()
                .font(.title2)

            Text("general.until")
                .font(.title2)

            Text(getDateString(start: false, end: true))
                .bold()
                .font(.title2)
        }
        .padding(.bottom, 25)
    }
}

/// A view which presents the results calculated by the CheapestHourManager of when the cheapest hours for the usage of energy are.
struct CheapestTimeResultView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    @EnvironmentObject var currentSetting: CurrentSetting

    var todayDateFormatter: DateFormatter
    let currencyFormatter: NumberFormatter

    init() {
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

                CheapestTimeResultTimeRange()

                HStack(alignment: .center) {
                    Text("cheapestPriceResultPage.totalTime")
                    Text(getTotalTime())
                        .bold()
                }

                Spacer(minLength: 0)

                // The clock which visually presents the results.
                HStack(spacing: 10) {
                    CheapestTimeClockView(cheapestHourManager.cheapestHoursForUsage!)
                        .padding([.leading, .trailing], 20)
                        .frame(width: 310, height: 310)
                }

                Spacer(minLength: 0)

                HStack(alignment: .center) {
                    Text("general.today")
                    Text(todayDateFormatter.string(from: Date()))
                        .bold()
                }
                .font(.callout)

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
        .onChange(of: currentSetting.entity!.awattarTariffIndex) { _ in
            // The tariff selection has affects on the hourly price which was calculated previously. That's why it has to be recalculated when the tariff selection changes.
            if cheapestHourManager.cheapestHoursForUsage != nil {
                cheapestHourManager.cheapestHoursForUsage!.calculateHourlyPrice(currentSetting: currentSetting)
            }
        }
        .onChange(of: currentSetting.entity!.awattarBaseElectricityPrice) { _ in
            if cheapestHourManager.cheapestHoursForUsage != nil {
                cheapestHourManager.cheapestHoursForUsage!.calculateHourlyPrice(currentSetting: currentSetting)
            }
        }
        .navigationTitle("general.result")
    }
}
