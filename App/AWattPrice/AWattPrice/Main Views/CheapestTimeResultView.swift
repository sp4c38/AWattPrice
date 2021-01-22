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
    }
}

struct CheapestTimeResultViewClock: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    var clockSize: CGFloat = 0
    
    func getClockSize() -> CGFloat {
        let screenSize = UIScreen.main.bounds.width
        let clockSize = screenSize * 0.85
        return clockSize
    }
    
    var body: some View {
        HStack(spacing: 10) {
            CheapestTimeClockView(cheapestHourManager.cheapestHoursForUsage!)
                .padding([.leading, .trailing], 20)
                .frame(
                    width: getClockSize(),
                    height: getClockSize()
                )
        }
    }
}

/// A view which presents the results calculated by the CheapestHourManager of when the cheapest hours for the usage of energy are.
struct CheapestTimeResultView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    @EnvironmentObject var currentSetting: CurrentSetting

    var todayDateFormatter: DateFormatter

    init() {
        todayDateFormatter = DateFormatter()
        todayDateFormatter.dateStyle = .long
        todayDateFormatter.timeStyle = .none
    }

    func getTotalTime() -> String {
        let firstItemStart = Date(
            timeIntervalSince1970:
                TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp)
        )
        let maxPointIndex = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.count - 1
        let lastItemEnd = Date(
            timeIntervalSince1970:
                TimeInterval(cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[maxPointIndex].endTimestamp)
        )
        let interval = Int(lastItemEnd.timeIntervalSince(firstItemStart))
        let hours = Int(
            (Double(interval) / 3600)
                .rounded(.down)
        )
        let minutes: Int = Int(
            (Double(interval % 3600) / 60)
                .rounded()
        )
        return TotalTimeFormatter().localizedTotalTimeString(hour: hours, minute: minutes)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if cheapestHourManager.cheapestHoursForUsage != nil {
                Spacer(minLength: 0)
                
                CheapestTimeResultTimeRange()

                Spacer(minLength: 0)
                
                HStack(alignment: .center) {
                    Text("cheapestPriceResultPage.totalTime")
                    Text(getTotalTime())
                        .bold()
                }
                
                Spacer(minLength: 0)

                CheapestTimeResultViewClock()

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
        .navigationTitle("general.result")
        .onAppear {
            cheapestHourManager.calculateCheapestHours(energyData: backendComm.energyData!, currentSetting: currentSetting)
        }
        .onChange(of: currentSetting.entity!.awattarTariffIndex) { _ in
            // The tariff selection has affects on the hourly price which was calculated previously. That's why it has to be recalculated when the tariff selection changes.
            if cheapestHourManager.cheapestHoursForUsage != nil {
                cheapestHourManager.cheapestHoursForUsage!.calculateHourlyPrice(currentSetting: currentSetting)
            }
        }
    }
}
