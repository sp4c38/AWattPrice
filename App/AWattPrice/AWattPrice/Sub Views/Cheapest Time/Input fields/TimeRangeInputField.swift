//
//  TimeRangeInputField.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.10.20.
//

import SwiftUI

/// A input field for the time range in the consumption comparison view.
struct TimeRangeInputField: View {
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var inputDateRange: ClosedRange<Date> = Date() ... Date()

    let errorValues: [Int]
    let totalTimeFormatter: TotalTimeFormatter

    init(errorValues: [Int]) {
        self.errorValues = errorValues
        totalTimeFormatter = TotalTimeFormatter()
    }

    func getMinRangeNeededString() -> String {
        let minTimeNeeded = (cheapestHourManager.timeOfUsage * 100).rounded(.up) / 100
        let hours = minTimeNeeded.rounded(.down)
        let minutes = ((minTimeNeeded - hours) * 100).rounded() / 100 * 60
        let totalTimeString = totalTimeFormatter.localizedTotalTimeString(hour: hours, minute: minutes)
        var baseString = "cheapestPricePage.inputMode.withDuration.wrongTimeRangeError"
        if cheapestHourManager.inputMode == 1 {
            baseString = "cheapestPricePage.inputMode.withKwh.wrongTimeRangeError"
        }
        return String(format: baseString.localized(), totalTimeString)
    }

    func setTimeIntervalValues() {
        if let minMaxTimeRange = awattarData.minMaxTimeRange {
            let minTime = minMaxTimeRange.lowerBound.addingTimeInterval(+1)
            let maxTime = minMaxTimeRange.upperBound.addingTimeInterval(-1)
            cheapestHourManager.endDate = maxTime
            inputDateRange = minTime ... maxTime
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("cheapestPricePage.timeRange")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("general.from")
                        .bold()
                        .font(.callout)
                        .foregroundColor(colorScheme == .light ? Color(hue: 0.0000, saturation: 0.0000, brightness: 0.4314) : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8311))

                    Spacer()

                    ComparisonDatePicker(selection: $cheapestHourManager.startDate, in: inputDateRange)
                        .frame(width: 165, height: 40)
                }
                .padding(5)
                .padding([.leading, .trailing], 2)
                .background(
                    colorScheme == .light ?
                        Color(red: 0.96, green: 0.95, blue: 0.97) :
                        Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424)
                )
                .cornerRadius(7)
                .ifTrue(errorValues.contains(5)) { content in
                    content
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.red, lineWidth: 2)
                        )
                }

                HStack {
                    Text("general.to")
                        .bold()
                        .font(.callout)
                        .foregroundColor(colorScheme == .light ? Color(hue: 0.0000, saturation: 0.0000, brightness: 0.4314) : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8311))

                    Spacer()

                    ComparisonDatePicker(selection: $cheapestHourManager.endDate, in: inputDateRange)
                        .frame(width: 167, height: 40)
                }
                .padding(5)
                .padding([.leading, .trailing], 2)
                .background(
                    colorScheme == .light ?
                        Color(red: 0.96, green: 0.95, blue: 0.97) :
                        Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424)
                )
                .cornerRadius(7)
                .ifTrue(errorValues.contains(5)) { content in
                    content
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.red, lineWidth: 2)
                        )
                }

                if errorValues.contains(5) {
                    Text(getMinRangeNeededString())
                        .font(.caption)
                        .foregroundColor(Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 20)

            HStack(alignment: .center) {
                Button(action: {
                    cheapestHourManager.setTimeIntervalThisNight(energyData: awattarData.energyData!)
                }) {
                    Text("cheapestPricePage.todayTonight")
                        .bold()
                }
                .buttonStyle(TimeRangeButtonStyle())

                Button(action: {
                    cheapestHourManager.setTimeInterval(forNextHourAmount: 3, energyData: awattarData.energyData!)
                }) {
                    Text("cheapestPricePage.nextThreeHours")
                        .bold()
                }
                .buttonStyle(TimeRangeButtonStyle())

                Button(action: {
                    cheapestHourManager.setTimeInterval(forNextHourAmount: 12, energyData: awattarData.energyData!)
                }) {
                    Text("cheapestPricePage.nextTwelveHours")
                        .bold()
                }
                .buttonStyle(TimeRangeButtonStyle())
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .onReceive(awattarData.$energyData) { _ in
            self.setTimeIntervalValues()
        }
    }
}

struct TimeRangeInputField_Previews: PreviewProvider {
    static var previews: some View {
        TimeRangeInputField(errorValues: [])
            .environmentObject(AwattarData())
            .environmentObject(CheapestHourManager())
            .padding()
    }
}
