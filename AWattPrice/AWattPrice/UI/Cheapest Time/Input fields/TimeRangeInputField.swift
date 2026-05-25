//
//  TimeRangeInputField.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.10.20.
//

import SwiftUI
import Combine

private enum TimeRangeQuickPreset: CaseIterable, Identifiable {
    case tonight
    case next3Hours
    case next12Hours
    case fullRange

    var id: Self { self }

    var title: String {
        switch self {
        case .tonight:
            return "Tonight"
        case .next3Hours:
            return "Next 3 hours"
        case .next12Hours:
            return "Next 12 hours"
        case .fullRange:
            return "All available"
        }
    }

    var icon: String {
        switch self {
        case .tonight:
            return "moon.stars.fill"
        case .next3Hours:
            return "clock"
        case .next12Hours:
            return "clock.arrow.circlepath"
        case .fullRange:
            return "arrow.up.left.and.arrow.down.right"
        }
    }
}

private struct TimeRangePresetButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let preset: TimeRangeQuickPreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(cheapestTimeAccent)

                Text(preset.title.localized())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        colorScheme == .light
                            ? cheapestTimeAccent.opacity(0.08)
                            : cheapestTimeAccent.opacity(0.18)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        colorScheme == .light
                            ? cheapestTimeAccent.opacity(0.16)
                            : cheapestTimeAccent.opacity(0.22),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TimeRangeInputFieldSelectionPart: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var partSelection: Date

    let name: String
    let systemImage: String
    let range: ClosedRange<Date>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(cheapestTimeAccent)

                Text(name.localized())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            DatePicker(
                "",
                selection: $partSelection,
                in: range,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.fieldBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.cardStroke(for: colorScheme), lineWidth: 1)
        )
    }
}

/// A input field for the time range in the consumption comparison view.
struct TimeRangeInputField: View {
    @Environment(\.colorScheme) private var colorScheme

    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var cheapestHourManager: CheapestHourManager

    @State var inputDateRange: ClosedRange<Date> = Date() ... Date()
    @State private var observedCurrentMinute = currentMinuteStart()

    private let minuteTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Time range", systemImage: "calendar.badge.clock")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(TimeRangeQuickPreset.allCases) { preset in
                    TimeRangePresetButton(preset: preset) {
                        apply(preset: preset)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                TimeRangeInputFieldSelectionPart(
                    partSelection: $cheapestHourManager.startDate,
                    name: "Earliest start",
                    systemImage: "arrow.forward.circle.fill",
                    range: inputDateRange
                )

                TimeRangeInputFieldSelectionPart(
                    partSelection: $cheapestHourManager.endDate,
                    name: "Latest finish",
                    systemImage: "flag.circle.fill",
                    range: inputDateRange
                )
            }

            if cheapestHourManager.showsTimeRangeError {
                Label(getMinRangeNeededString(), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.error)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.subtleFill(AppTheme.error, for: colorScheme))
                    )
                    .id("TimeRangeInputFieldErrorText" + getMinRangeNeededString())
            }
        }
        .cheapestTimeCardStyle()
        .onReceive(energyDataService.$energyData) { _ in
            setTimeIntervalValues()
        }
        .onAppear {
            updateStartDateMinimum(Date())
        }
        .onReceive(minuteTimer) { now in
            updateStartDateMinimumOnMinuteChange(now)
        }
        .onChange(of: cheapestHourManager.startDate) {
            cheapestHourManager.resetTransientState()
        }
        .onChange(of: cheapestHourManager.endDate) {
            cheapestHourManager.resetTransientState()
        }
    }
}

extension TimeRangeInputField {
    // Helper functions

    private static func currentMinuteStart(for date: Date = Date()) -> Date {
        Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date
    }

    private func updateStartDateMinimumOnMinuteChange(_ now: Date) {
        let newCurrentMinute = Self.currentMinuteStart(for: now)
        guard newCurrentMinute != observedCurrentMinute else { return }

        observedCurrentMinute = newCurrentMinute
        updateStartDateMinimum(newCurrentMinute)
    }

    private func updateStartDateMinimum(_ now: Date) {
        let currentMinute = Self.currentMinuteStart(for: now)
        let selectedStartMinute = Self.currentMinuteStart(for: cheapestHourManager.startDate)
        guard selectedStartMinute < currentMinute else { return }
        guard inputDateRange.contains(currentMinute) else { return }
        cheapestHourManager.startDate = currentMinute
    }

    /// Set the max upper and lower bound for the time range input
    func setTimeIntervalValues() {
        if let energyData = energyDataService.energyData,
           let minMaxTimeRange = energyData.minMaxTimeRange
        {
            let minTime = minMaxTimeRange.lowerBound.addingTimeInterval(+1)
            let maxTime = minMaxTimeRange.upperBound.addingTimeInterval(-1)
            if cheapestHourManager.startDate < minTime || cheapestHourManager.startDate > maxTime {
                cheapestHourManager.startDate = minTime
            }
            cheapestHourManager.endDate = maxTime
            inputDateRange = minTime ... maxTime
        }
    }

    private func apply(preset: TimeRangeQuickPreset) {
        guard let energyData = energyDataService.energyData else { return }

        switch preset {
        case .tonight:
            cheapestHourManager.setTimeIntervalThisNight(with: energyData)
        case .next3Hours:
            cheapestHourManager.setTimeInterval(forHours: 3, with: energyData)
        case .next12Hours:
            cheapestHourManager.setTimeInterval(forHours: 12, with: energyData)
        case .fullRange:
            cheapestHourManager.setMaxTimeInterval(with: energyData)
        }

        cheapestHourManager.resetTransientState()
    }

    /// Get error string indicating minimum time range needed.
    func getMinRangeNeededString() -> String {
        let totalTimeFormatter = TotalTimeFormatter()
        
        let hours = Int(
            (Double(cheapestHourManager.timeOfUsage) / 3600)
                .rounded(.down)
        )
        let minutes = Int(
            (Double(cheapestHourManager.timeOfUsage % 3600) / 60)
                .rounded()
        )
        let totalTimeString = totalTimeFormatter.string(
            hour: hours, minute: minutes
        )
        let baseString = "cheapestPricePage.inputMode.withDuration.wrongTimeRangeError"
        return String(format: baseString.localized(), totalTimeString)
    }
}

struct TimeRangeInputField_Previews: PreviewProvider {
    static var previews: some View {
        TimeRangeInputField()
            .environmentObject(CheapestHourManager())
            .padding()
    }
}
