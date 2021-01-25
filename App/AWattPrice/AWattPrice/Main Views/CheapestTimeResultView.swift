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
            var startDate = Date(timeIntervalSince1970: 0)
            if start == true {
                startDate = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.first!.startTimestamp
            } else if end == true {
                startDate = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.last!.endTimestamp
            }
            return dateFormatter.string(from: startDate)
        } else {
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            Text(getDateString(start: true, end: false))
                .bold()
            
            Text("general.until")

            Text(getDateString(start: false, end: true))
                .bold()
        }
        .font(.fTitle2)
    }
}

struct CheapestTimeResultViewClock: View {
    @Environment(\.deviceOrientation) var deviceOrientation
    @Environment(\.deviceType) var deviceType
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var clockSize: CGFloat = 310

    func getClockSize(_ deviceOrientation: UIInterfaceOrientation) {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        var screenSizeValue: CGFloat = 310
        if deviceType == .phone {
            screenSizeValue = screenWidth
        } else {
            if deviceOrientation.isLandscape {
                screenSizeValue = screenHeight - 50
            } else {
                screenSizeValue = screenWidth
            }
        }
        
        if deviceType == .phone {
            clockSize = screenSizeValue * 0.80
        } else {
            clockSize = screenSizeValue * 0.55
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            CheapestTimeClockView(cheapestHourManager.cheapestHoursForUsage!)
                .padding([.leading, .trailing], 20)
                .frame(
                    width: clockSize,
                    height: (clockSize - 20)
                )
        }
        .onAppear {
            getClockSize(deviceOrientation.deviceOrientation)
        }
        .onReceive(deviceOrientation.$deviceOrientation) { newDeviceOrientation in
            getClockSize(newDeviceOrientation)
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
        let firstItemStart = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[0].startTimestamp
        let lastItemEnd = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.last!.endTimestamp
        let interval = Int(lastItemEnd.timeIntervalSince(firstItemStart))
        let hours = Int(
            (Double(interval) / 3600)
                .rounded(.down)
        )
        let minutes = Int(
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
                .font(.fBody)

                Spacer(minLength: 0)

                CheapestTimeResultViewClock()

                Spacer(minLength: 0)

                HStack(alignment: .center) {
                    Text("general.today")
                    Text(todayDateFormatter.string(from: Date()))
                        .bold()
                }
                .font(.fCallout)

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
//        .onChange(of: currentSetting.entity!.awattarTariffIndex) { _ in
//            // The tariff selection has affects on the hourly price which was calculated previously. That's why it has to be recalculated when the tariff selection changes.
//            if cheapestHourManager.cheapestHoursForUsage != nil {
//                cheapestHourManager.cheapestHoursForUsage!.calculateHourlyPrice(currentSetting: currentSetting)
//            }
//        }
    }
}
