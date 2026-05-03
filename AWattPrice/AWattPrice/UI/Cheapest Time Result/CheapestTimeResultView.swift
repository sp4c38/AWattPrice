//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import SwiftUI

private struct CheapestTimeMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct CheapestTimeTimelineRow: View {
    let startTime: Date
    let endTime: Date
    let priceText: String
    let note: String?
    let isLast: Bool

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .top) {
                if !isLast {
                    Rectangle()
                        .fill(cheapestTimeAccent.opacity(0.22))
                        .frame(width: 2)
                        .padding(.top, 5)
                }

                Circle()
                    .fill(cheapestTimeAccent)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 10, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(timeFormatter.string(from: startTime)) - \(timeFormatter.string(from: endTime))")
                    .font(.headline)

                if let note {
                    Text(note.localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(priceText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.bottom, note == nil ? 0 : 8)
    }
}

private struct CheapestTimeTimelineEntry: Identifiable {
    let id: Int
    let startTime: Date
    let endTime: Date
    let priceText: String
}

private struct CheapestTimeResultContent: View {
    let result: HourPair

    private var heroTitle: String {
        "Cheapest Time".localized()
    }

    private var windowText: String {
        guard let startDate = result.startDate, let endDate = result.endDate else { return "" }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEE"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let calendar = Calendar.current
        let relativeDay: String
        if calendar.isDateInToday(startDate) {
            relativeDay = "Today".localized()
        } else if calendar.isDateInTomorrow(startDate) {
            relativeDay = "Tomorrow".localized()
        } else {
            relativeDay = ""
        }

        let weekday = weekdayFormatter.string(from: startDate)
        let prefix = relativeDay.isEmpty ? weekday : "\(relativeDay), \(weekday)"

        return "\(prefix) \(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))"
    }

    private var durationText: String {
        let totalSeconds = Int(result.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return TotalTimeFormatter().string(hour: hours, minute: minutes)
    }

    private var averagePriceText: String {
        "\(result.averagePrice.priceString ?? "-") ct/kWh"
    }

    private var timelineEntries: [CheapestTimeTimelineEntry] {
        guard let resultStart = result.startDate, let resultEnd = result.endDate else { return [] }

        return result.associatedPricePoints.enumerated().compactMap { index, pricePoint in
            let displayStart = max(pricePoint.startTime, resultStart)
            let displayEnd = min(pricePoint.endTime, resultEnd)
            guard displayStart < displayEnd else { return nil }

            return CheapestTimeTimelineEntry(
                id: index,
                startTime: displayStart,
                endTime: displayEnd,
                priceText: "\(pricePoint.marketprice.priceString ?? "-") ct/kWh"
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(heroTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(windowText)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .cheapestTimeCardStyle()

                HStack(spacing: 12) {
                    CheapestTimeMetricCard(title: "Duration", value: durationText, systemImage: "timer")
                    CheapestTimeMetricCard(title: "Average Price", value: averagePriceText, systemImage: "bolt.fill")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Timeline", systemImage: "list.bullet.rectangle.portrait")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(timelineEntries.enumerated()), id: \.element.id) { index, entry in
                            let isFirst = index == 0
                            let isLast = index == timelineEntries.count - 1

                            CheapestTimeTimelineRow(
                                startTime: entry.startTime,
                                endTime: entry.endTime,
                                priceText: entry.priceText,
                                note: isFirst ? "Recommended start" : (isLast ? "Recommended end" : nil),
                                isLast: isLast
                            )
                        }
                    }
                }
                .cheapestTimeCardStyle()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
    }
}

struct CheapestTimeResultView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var cheapestHourManager: CheapestHourManager

    @State private var displayedResult: HourPair?
    @State private var didStartCalculation = false

    var body: some View {
        Group {
            if let result = displayedResult {
                CheapestTimeResultContent(result: result)
            } else if cheapestHourManager.failedToFindResult {
                ContentUnavailableView(
                    "No Result Found",
                    systemImage: "bolt.slash",
                    description: Text("cheapestPriceResultPage.cheapestTimeErrorOccurred".localized())
                )
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Finding cheapest time...".localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Cheapest Time")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didStartCalculation else { return }
            didStartCalculation = true

            if let energyData = energyDataService.energyData {
                cheapestHourManager.calculateCheapestHours(energyData: energyData)
            }
        }
        .onReceive(cheapestHourManager.$result) { result in
            guard displayedResult == nil else { return }
            displayedResult = result
        }
    }
}

struct CheapestTimeResultView_Previews: PreviewProvider {
    static var associatedPricePoints: [EnergyPricePoint] = {
        let prices = EnergyData.previewContent().currentPrices
        return Array(prices.prefix(3))
    }()

    static var previews: some View {
        let cheapestHourManager: CheapestHourManager = {
            let cheapestHourManager = CheapestHourManager()
            cheapestHourManager.setPreviewResult(HourPair(associatedPricePoints: associatedPricePoints))
            return cheapestHourManager
        }()

        CheapestTimeResultView()
            .environmentObject(cheapestHourManager)
            .environmentObject(EnergyDataService())
    }
}
