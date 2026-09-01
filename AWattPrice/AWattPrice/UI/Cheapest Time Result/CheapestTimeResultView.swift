//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import SwiftUI

private struct CheapestTimeMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme

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
                .fill(AppTheme.fieldBackground(for: colorScheme))
        )
    }
}

private struct CheapestTimeTimelineRow: View {
    let startTime: Date
    let endTime: Date
    let priceText: String
    let marker: CheapestTimeTimelineMarker?

    static let markerColumnWidth: CGFloat = 20

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                if marker != nil {
                    Circle()
                        .fill(cheapestTimeAccent)
                        .frame(width: 10, height: 10)
                }
            }
            .frame(width: Self.markerColumnWidth, height: Self.markerColumnWidth)

            Text("\(timeFormatter.string(from: startTime)) - \(timeFormatter.string(from: endTime))")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text(priceText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private enum CheapestTimeTimelineMarker {
    case start
    case end
}

private struct CheapestTimeTimelineEntry: Identifiable {
    let id: Int
    let startTime: Date
    let endTime: Date
    let priceText: String
}

private struct CheapestTimeMetricCardData: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
}

private struct CheapestTimeResultContent: View {
    let result: HourPair

    // Only drives the "Starts In" countdown text below; the result itself is
    // calculated once and never recomputed from this ticking.
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// First line of the hero window display — the relative day ("Today,"), if any.
    private var windowLinePrefix: String? {
        guard let startDate = result.startDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(startDate) {
            return "\("Today".localized()),"
        } else if calendar.isDateInTomorrow(startDate) {
            return "\("Tomorrow".localized()),"
        }
        return nil
    }

    /// Second line of the hero window display — weekday and time range.
    private var windowLine: String {
        guard let startDate = result.startDate, let endDate = result.endDate else { return "" }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEE"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let weekday = weekdayFormatter.string(from: startDate)
        return "\(weekday) \(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))"
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

    private var hasStarted: Bool {
        guard let startDate = result.startDate else { return false }
        return startDate.timeIntervalSince(now) <= 0
    }

    private var startsInText: String {
        guard let startDate = result.startDate else { return "" }
        let secondsUntilStart = Int(startDate.timeIntervalSince(now))
        guard secondsUntilStart > 0 else { return "" }

        let hours = secondsUntilStart / 3600
        let minutes = (secondsUntilStart % 3600) / 60
        return TotalTimeFormatter().string(hour: hours, minute: minutes)
    }

    /// "Starts In"/countdown before the window begins, "Status"/"In Progress" once it has.
    private var startsInCard: CheapestTimeMetricCardData {
        if hasStarted {
            return CheapestTimeMetricCardData(id: "startsIn", title: "Status", value: "In Progress".localized(), systemImage: "hourglass.bottomhalf.fill")
        }
        return CheapestTimeMetricCardData(id: "startsIn", title: "Starts In", value: startsInText, systemImage: "hourglass")
    }

    private var metricCards: [CheapestTimeMetricCardData] {
        [
            startsInCard,
            CheapestTimeMetricCardData(id: "duration", title: "Duration", value: durationText, systemImage: "timer"),
            CheapestTimeMetricCardData(id: "averagePrice", title: "Average Price", value: averagePriceText, systemImage: "bolt.fill"),
        ]
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
                priceText: pricePoint.marketprice.priceString ?? "-"
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    if let windowLinePrefix {
                        Text(windowLinePrefix)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Text(windowLine)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .cheapestTimeCardStyle()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(metricCards) { card in
                        CheapestTimeMetricCard(title: card.title, value: card.value, systemImage: card.systemImage)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Timeline", systemImage: "list.bullet.rectangle.portrait")
                            .font(.headline)

                        Spacer()

                        Text("ct/kWh".localized())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(timelineEntries.enumerated()), id: \.element.id) { index, entry in
                            let isFirst = index == 0
                            let isLast = index == timelineEntries.count - 1

                            CheapestTimeTimelineRow(
                                startTime: entry.startTime,
                                endTime: entry.endTime,
                                priceText: entry.priceText,
                                marker: isFirst ? .start : (isLast ? .end : nil)
                            )
                        }
                    }
                    .background(alignment: .leading) {
                        // One continuous rail connecting the start and end markers,
                        // instead of a separate line segment per row. Rows are a fixed
                        // height now (no notes), so both insets are just half that height.
                        Rectangle()
                            .fill(Color.secondary.opacity(0.18))
                            .frame(width: 2)
                            .padding(.vertical, CheapestTimeTimelineRow.markerColumnWidth / 2)
                            .padding(.leading, (CheapestTimeTimelineRow.markerColumnWidth - 2) / 2)
                    }
                }
                .cheapestTimeCardStyle()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .onReceive(timer) { now = $0 }
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
        .appScreenBackground()
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
