//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import Resolver
import SwiftUI

struct CheapestTimeResultTimeRange: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var startDate: Date? = nil
    @State var startDifferenceString = ""
    @State var endDate: Date? = nil
    @State var endDifferenceString = ""
    
    let updateTimer = Timer.publish(every: 2, on: .main, in: .default).autoconnect()
    
    var body: some View {
        VStack(alignment: .center, spacing: 7) {
            if startDate != nil {
                VStack(spacing: 4) {
                    Text(getDateString(startDate!))
                        .bold()
                    Text("in \(startDifferenceString)")
                        .bold()
                        .modifier(DifferenceTimeModifier())
                }
            }

            
            Text("general.until")

            if endDate != nil {
                VStack(spacing: 4) {
                    Text(getDateString(endDate!))
                        .bold()
                    Text("in \(endDifferenceString)")
                        .bold()
                        .modifier(DifferenceTimeModifier())
                }
            }
        }
        .font(.fTitle2)
        .onReceive(cheapestHourManager.$startDate) { _ in setStart() }
        .onReceive(cheapestHourManager.$endDate) { _ in setEnd() }
        .onReceive(updateTimer) { _ in
            setStart()
            setEnd()
        }
    }
    
    func setStart() {
        startDate = getDate(.start)
        startDifferenceString = getNowDifferenceString(referencingTo: startDate!)
    }
    func setEnd() {
        endDate = getDate(.end)
        endDifferenceString = getNowDifferenceString(referencingTo: endDate!)
    }
    
    struct DifferenceTimeModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.fCallout)
                .foregroundColor(.gray)
        }
    }
}

extension CheapestTimeResultTimeRange {
    enum DateType {
        case start
        case end
    }
    
    func getDate(_ dateType: DateType) -> Date {
        let pricePoints = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints
        
        var useDate: Date? = nil
        switch dateType {
        case .start:
            useDate = pricePoints.first!.startTime
        case .end:
            useDate = pricePoints.last!.endTime
        }
        
        return useDate!
    }
    
    func getDateString(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let dateString = dateFormatter.string(from: date)
        return dateString
    }
    
    func getNowDifferenceString(referencingTo referenceDate: Date) -> String {
        let timeFormatter = TotalTimeFormatter()
        
        let now = Date()
        let difference = referenceDate.timeIntervalSince(now)
        
        let hours = Int(
            (difference / 3600)
                .rounded(.down)
        )
        let minutes = Int(
            (Double(Int(difference) % 3600) / 60)
                .rounded(.up)
        )
        
        let differenceString = timeFormatter.string(
            hour: hours, minute: minutes
        )
        
        return differenceString
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
                    height: clockSize - 20
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
    @Injected var energyDataController: EnergyDataController
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    @Injected var currentSetting: CurrentSetting

    var todayDateFormatter: DateFormatter

    init() {
        todayDateFormatter = DateFormatter()
        todayDateFormatter.dateStyle = .long
        todayDateFormatter.timeStyle = .none
    }

    func getTotalTime() -> String {
        let firstItemStart = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints[0].startTime
        let lastItemEnd = cheapestHourManager.cheapestHoursForUsage!.associatedPricePoints.last!.endTime
        let interval = Int(lastItemEnd.timeIntervalSince(firstItemStart))
        let hours = Int(
            (Double(interval) / 3600)
                .rounded(.down)
        )
        let minutes = Int(
            (Double(interval % 3600) / 60)
                .rounded()
        )
        return TotalTimeFormatter().string(hour: hours, minute: minutes)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if cheapestHourManager.cheapestHoursForUsage != nil {
                Spacer(minLength: 0)

                CheapestTimeResultTimeRange()

                Spacer(minLength: 0)

                CheapestTimeResultViewClock()

                Spacer(minLength: 0)
                
                HStack(alignment: .center) {
                    Text("cheapestPriceResultPage.duration")
                    Text(getTotalTime())
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
            cheapestHourManager.calculateCheapestHours(energyData: energyDataController.energyData!, currentSetting: currentSetting)
        }
    }
}

struct CheapestTimeResultView_Previews: PreviewProvider {
    static var associatedPricePoints: [EnergyPricePoint] = {
        let prices = EnergyData.previewContent().prices
        return [prices[0]]
    }()
    
    static var previews: some View {
        
        let cheapestHourManager: CheapestHourManager = {
            let cheapestHourManager = CheapestHourManager()
            cheapestHourManager.cheapestHoursForUsage = HourPair(
                associatedPricePoints: associatedPricePoints
            )
            return cheapestHourManager
        }()
        
        CheapestTimeResultTimeRange()
            .environmentObject(cheapestHourManager)
    }
}
