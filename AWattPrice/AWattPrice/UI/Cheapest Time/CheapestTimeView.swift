//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

let cheapestTimeAccent = Color(red: 0.87, green: 0.35, blue: 0.26)

struct CheapestTimeViewBodyPicker: View {
    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var maxTimeInterval = TimeInterval(3600)

    func setMaxTimeInterval() {
        guard let minMaxTimeRange = energyDataService.energyData?.minMaxTimeRange else { return }
        let nowHourStart = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: Date()),
            minute: 0,
            second: 0,
            of: Date()
        )!
        let nowHourEnd = nowHourStart.addingTimeInterval(3600)
        var differenceTimeInterval: Double = TimeInterval()
        if minMaxTimeRange.lowerBound >= nowHourStart, minMaxTimeRange.lowerBound <= nowHourEnd {
            differenceTimeInterval = TimeInterval(
                nowHourStart.timeIntervalSince(
                    Date()
                ).rounded(.up)
            )
        }
        maxTimeInterval = (minMaxTimeRange.upperBound.timeIntervalSince(minMaxTimeRange.lowerBound)) + differenceTimeInterval
    }

    var body: some View {
        VStack {
            EasyIntervalPickerRepresentable(
                $cheapestHourManager.timeOfUsageInterval,
                maxTimeInterval: maxTimeInterval,
                selectionInterval: 5
            )
            .frame(width: 275) // The UI View won't apply to this property. But it makes sure that the time interval picker won't go outside of display borders (i.e. on iPhone SE).
            .onAppear {
                setMaxTimeInterval()
            }
            .onReceive(energyDataService.$energyData) { _ in
                setMaxTimeInterval()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct CheapestTimeCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .light
                                ? [Color.white, Color(red: 0.98, green: 0.97, blue: 0.95)]
                                : [Color(red: 0.13, green: 0.13, blue: 0.15), Color(red: 0.09, green: 0.09, blue: 0.11)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        colorScheme == .light
                            ? Color.black.opacity(0.05)
                            : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.06) : Color.black.opacity(0.25),
                radius: 16,
                y: 8
            )
    }
}

extension View {
    func cheapestTimeCardStyle() -> some View {
        modifier(CheapestTimeCardModifier())
    }
}

private struct CheapestTimeDurationSection: View {
    @EnvironmentObject private var cheapestHourManager: CheapestHourManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Duration", systemImage: "timer")
                .font(.headline)
                .foregroundStyle(.primary)

            CheapestTimeViewBodyPicker()
        }
        .cheapestTimeCardStyle()
        .onChange(of: cheapestHourManager.timeOfUsageInterval) {
            cheapestHourManager.resetTransientState()
        }
    }
}

private struct CheapestTimeResultButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("Calculate results")
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cheapestTimeAccent)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A view which allows the user to find the cheapest time window for a given duration.
struct CheapestTimeView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var cheapestHourManager: CheapestHourManager

    @State private var navigateToResults = false

    private var hasCurrentPriceData: Bool {
        energyDataService.energyData?.currentPrices.isEmpty == false
    }

    var body: some View {
        Group {
            if hasCurrentPriceData {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Find the cheapest time for a selected duration within a time range.".localized())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        CheapestTimeDurationSection()
                        TimeRangeInputField()
                        CheapestTimeResultButton {
                            cheapestHourManager.validateInputs()
                            if cheapestHourManager.hasValidInput {
                                navigateToResults = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            } else {
                DataDownloadAndError()
            }
        }
        .navigationTitle("Cheapest Time")
        .navigationDestination(isPresented: $navigateToResults) {
            CheapestTimeResultView()
        }
    }
}

struct CheapestTimeView_Previews: PreviewProvider {
    static let energyDataService = EnergyDataService()

    static var previews: some View {
        NavigationStack {
            CheapestTimeView()
                .environmentObject(energyDataService)
                .environmentObject(CheapestHourManager())
                .onAppear { energyDataService.download(setting: SettingsManager.shared.setting) }
        }
    }
}
