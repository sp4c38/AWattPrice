//
//  TimeRangeInputField.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.10.20.
//

import SwiftUI

struct TimeRangeInputFieldSelectionPartModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    func body(content: Content) -> some View {
        content
            .padding(5)
            .padding([.leading, .trailing], 2)
            .background(
                colorScheme == .light ?
                    Color(red: 0.96, green: 0.95, blue: 0.97) :
                    Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424)
            )
            .cornerRadius(7)
            .ifTrue(cheapestHourManager.errorValues.contains(5)) { content in
                content
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.red, lineWidth: 2)
                    )
            }
    }
}

struct TimeRangeInputFieldSelectionPart: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var partSelection: Date

    let name: String
    let range: ClosedRange<Date>

    init(withName name: String, selection: Binding<Date>, in range: ClosedRange<Date>) {
        self.name = name
        _partSelection = selection
        self.range = range
    }

    var body: some View {
        HStack {
            Text(name.localized())
                .bold()
                .font(.fCallout)
                .foregroundColor(
                    colorScheme == .light ?
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.4314) :
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8311)
                )

            Spacer(minLength: 0)

            ComparisonDatePicker(selection: $partSelection, in: range)
                .frame(height: 35, alignment: .center)
        }
        .modifier(TimeRangeInputFieldSelectionPartModifier())
    }
}

struct TimeRangeInputFieldQuickSelectButtons: View {
    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var buttonSize = CGSize(width: 0, height: 0)

    var buttons = [
        "cheapestPricePage.todayTonight",
        "cheapestPricePage.nextThreeHours",
        "cheapestPricePage.nextTwelveHours",
        "cheapestPricePage.maximal",
    ]

    var gridLayout = [GridItem(.adaptive(minimum: 70), spacing: 0, alignment: .center)]

    var body: some View {
        LazyVGrid(columns: gridLayout, alignment: .center, spacing: 10) {
            ForEach(buttons, id: \.self) { name in
                Button(action: {
                    if name == "cheapestPricePage.todayTonight" {
                        cheapestHourManager.setTimeIntervalThisNight(with: backendComm.energyData!)
                    } else if name == "cheapestPricePage.maximal" {
                        cheapestHourManager.setMaxTimeInterval(with: backendComm.energyData!)
                    } else if name == "cheapestPricePage.nextThreeHours" {
                        cheapestHourManager.setTimeInterval(forHours: 3, with: backendComm.energyData!)
                    } else if name == "cheapestPricePage.nextTwelveHours" {
                        cheapestHourManager.setTimeInterval(forHours: 12, with: backendComm.energyData!)
                    }
                }) {
                    Text(name.localized())
                        .font(.fBody)
                        .fontWeight(.semibold)
                }
                .buttonStyle(TimeRangeButtonStyle())
            }
        }
        .padding(.top, 3)
    }
}

/// A input field for the time range in the consumption comparison view.
struct TimeRangeInputField: View {
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var inputDateRange: ClosedRange<Date> = Date() ... Date()

    let totalTimeFormatter: TotalTimeFormatter

    init() {
        totalTimeFormatter = TotalTimeFormatter()
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
                TimeRangeInputFieldSelectionPart(
                    withName: "general.from",
                    selection: $cheapestHourManager.startDate,
                    in: inputDateRange
                )

                TimeRangeInputFieldSelectionPart(
                    withName: "general.to",
                    selection: $cheapestHourManager.endDate,
                    in: inputDateRange
                )

                if cheapestHourManager.errorValues.contains(5) {
                    Text(getMinRangeNeededString())
                        .font(.caption)
                        .foregroundColor(Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .id("TimeRangeInputFieldErrorText" + getMinRangeNeededString())
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 15)

            TimeRangeInputFieldQuickSelectButtons()
        }
        .frame(maxWidth: .infinity)
        .onReceive(backendComm.$energyData) { _ in
            self.setTimeIntervalValues()
        }
    }
}

extension TimeRangeInputField {
    // Helper functions

    /// Set the max upper and lower bound for the time range input
    func setTimeIntervalValues() {
        if let minMaxTimeRange = backendComm.minMaxTimeRange {
            let minTime = minMaxTimeRange.lowerBound.addingTimeInterval(+1)
            let maxTime = minMaxTimeRange.upperBound.addingTimeInterval(-1)
            cheapestHourManager.endDate = maxTime
            inputDateRange = minTime ... maxTime
        }
    }

    /// Get error string indicating minimum time range needed.
    func getMinRangeNeededString() -> String {
        let hours = Int(
            (Double(cheapestHourManager.timeOfUsage) / 3600)
                .rounded(.down)
        )
        let minutes = Int(
            (Double(cheapestHourManager.timeOfUsage % 3600) / 60)
                .rounded()
        )
        let totalTimeString = totalTimeFormatter.localizedTotalTimeString(hour: hours, minute: minutes)
        var baseString = "cheapestPricePage.inputMode.withDuration.wrongTimeRangeError"
        if cheapestHourManager.inputMode == 1 {
            baseString = "cheapestPricePage.inputMode.withKwh.wrongTimeRangeError"
        }
        return String(format: baseString.localized(), totalTimeString)
    }
}

struct TimeRangeInputField_Previews: PreviewProvider {
    static var previews: some View {
        TimeRangeInputField()
            .environmentObject(BackendCommunicator())
            .environmentObject(CheapestHourManager())
            .padding()
    }
}
