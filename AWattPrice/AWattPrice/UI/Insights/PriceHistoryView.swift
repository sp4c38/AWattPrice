//
//  PriceHistoryView.swift
//  AWattPrice
//
//  Created by Codex on 25.08.26.
//

import SwiftUI
import Charts

private enum PriceHistoryRange: String, CaseIterable, Identifiable, Hashable {
    case month = "1mo"
    case quarter = "3mo"
    case year = "1yr"
    case twoYears = "2yr"

    var id: Self { self }

    var title: String {
        rawValue
    }

    var comparisonLabel: String {
        switch self {
        case .month: "previous month"
        case .quarter: "previous three months"
        case .year: "previous year"
        case .twoYears: "the preceding year"
        }
    }
}

private enum PriceHistoryLoadState {
    case loading
    case loaded([PriceHistoryRange: PriceStatisticsData])
    case failed
}

private extension PriceStatisticsData {
    var highlightTitle: String {
        switch highlight.kind {
        case "day": "Cheapest day"
        case "weekday": "Cheapest weekday"
        default: "Cheapest month"
        }
    }

    var highlightValue: String {
        if let timestamp = highlight.timestamp {
            return timestamp.formatted(date: .abbreviated, time: .omitted)
        }
        guard let value = highlight.value else { return "–" }
        let formatter = DateFormatter()
        switch highlight.kind {
        case "weekday":
            let symbols = formatter.weekdaySymbols ?? []
            let calendarIndex = value % 7
            return symbols.indices.contains(calendarIndex) ? symbols[calendarIndex] : "–"
        default:
            let symbols = formatter.monthSymbols ?? []
            let monthIndex = value - 1
            return symbols.indices.contains(monthIndex) ? symbols[monthIndex] : "–"
        }
    }
}

struct PriceHistoryNavigationCard: View {
    var body: some View {
        InsightsCard(tint: AppTheme.accent) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Price History")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Long-term statistics and trends")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PriceHistoryView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var selectedRange: PriceHistoryRange = .month
    @State private var loadState: PriceHistoryLoadState
    @State private var loadingRanges: Set<PriceHistoryRange> = []
    private let previewData: PriceStatisticsData?

    init(previewData: PriceStatisticsData? = nil) {
        self.previewData = previewData
        let previewRanges = previewData.map { sample in
            Dictionary(uniqueKeysWithValues: PriceHistoryRange.allCases.map { ($0, sample) })
        }
        _loadState = State(initialValue: previewRanges.map(PriceHistoryLoadState.loaded) ?? .loading)
    }

    private var requestKey: String {
        let setting = settingsManager.setting
        return [
            setting.marketAreaKey,
            String(setting.baseFeePrice),
            String(setting.percentagePriceAddOn),
            String(setting.taxEnabled),
            String(setting.monthlyFixedCost),
            String(setting.annualConsumptionKWh),
            setting.priceAddOnOrder,
        ].joined(separator: ":")
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Range", selection: $selectedRange) {
                ForEach(PriceHistoryRange.allCases) { range in
                    Text(range.title.localized())
                        .textCase(nil)
                        .tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Group {
                switch loadState {
                case .loading:
                    loadingView
                case .loaded(let histories):
                    if let history = histories[selectedRange] {
                        PriceHistoryContent(
                            history: history,
                            chartTrend: chartTrend(from: histories, for: selectedRange),
                            range: selectedRange
                        )
                            .transition(.opacity)
                    } else if loadingRanges.contains(selectedRange) {
                        loadingView
                    } else {
                        unavailableView
                    }
                case .failed:
                    unavailableView
                }
            }
        }
        .appScreenBackground()
        .navigationTitle("Price History")
        .navigationBarTitleDisplayMode(.large)
        .task(id: requestKey) {
            await loadHistories()
        }
        .animation(.easeInOut(duration: 0.4), value: selectedRange)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.accent)
            Text("Loading price history")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableView: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)
            Text("Price history unavailable")
                .font(.headline)
            Button("Try Again") {
                Task { await loadHistories() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadHistories() async {
        if let previewData {
            loadState = .loaded(
                Dictionary(uniqueKeysWithValues: PriceHistoryRange.allCases.map { ($0, previewData) })
            )
            return
        }
        loadState = .loading
        loadingRanges = Set(PriceHistoryRange.allCases)
        let setting = settingsManager.setting

        func download(_ range: PriceHistoryRange) async -> PriceStatisticsData? {
            do {
                let history = try await PriceStatisticsData.download(
                    marketArea: setting.marketArea,
                    range: range.rawValue,
                    pricingConfiguration: setting.pricingConfiguration
                )
                return history.coverage.isUsable ? history : nil
            } catch is CancellationError {
                return nil
            } catch {
                print("Price history download failed for \(range.rawValue): \(error).")
                return nil
            }
        }

        async let month = download(.month)
        async let quarter = download(.quarter)
        async let year = download(.year)
        async let twoYears = download(.twoYears)

        let loadedMonth = await month
        guard Task.isCancelled == false else { return }
        loadingRanges.remove(.month)

        if let loadedMonth {
            withAnimation(.easeInOut(duration: 0.25)) {
                loadState = .loaded([.month: loadedMonth])
            }
        }

        let remaining = await (quarter, year, twoYears)
        guard Task.isCancelled == false else { return }

        let histories = [
            PriceHistoryRange.month: loadedMonth,
            PriceHistoryRange.quarter: remaining.0,
            PriceHistoryRange.year: remaining.1,
            PriceHistoryRange.twoYears: remaining.2,
        ].compactMapValues { $0 }

        withAnimation(.easeInOut(duration: 0.25)) {
            loadState = histories.isEmpty ? .failed : .loaded(histories)
            loadingRanges.removeAll()
        }
    }

    private func chartTrend(
        from histories: [PriceHistoryRange: PriceStatisticsData],
        for selectedRange: PriceHistoryRange
    ) -> [PriceStatisticsData.TrendPoint] {
        let rangesFromLongestToShortest: [PriceHistoryRange] = [
            .twoYears,
            .year,
            .quarter,
            .month,
        ]
        guard let selectedTrend = histories[selectedRange]?.trend,
              let selectedStart = selectedTrend.first?.startTimestamp,
              let fallbackTrend = rangesFromLongestToShortest
                .compactMap({ histories[$0]?.trend })
                .first(where: { $0.isEmpty == false }) else {
            return []
        }

        let timestamps = Set(
            histories.values.flatMap { history in
                history.trend.map(\.startTimestamp)
            }
        )

        return timestamps.sorted().compactMap { timestamp in
            let sourceTrend = timestamp >= selectedStart ? selectedTrend : fallbackTrend
            guard let averagePrice = interpolatedAverage(at: timestamp, in: sourceTrend) else {
                return nil
            }
            return PriceStatisticsData.TrendPoint(
                startTimestamp: timestamp,
                averagePrice: averagePrice
            )
        }
    }

    private func interpolatedAverage(
        at timestamp: Date,
        in trend: [PriceStatisticsData.TrendPoint]
    ) -> Double? {
        guard let first = trend.first, let last = trend.last else { return nil }
        guard timestamp > first.startTimestamp else { return first.averagePrice }
        guard timestamp < last.startTimestamp else { return last.averagePrice }

        var lowerIndex = 0
        var upperIndex = trend.count - 1
        while lowerIndex + 1 < upperIndex {
            let middleIndex = (lowerIndex + upperIndex) / 2
            if trend[middleIndex].startTimestamp <= timestamp {
                lowerIndex = middleIndex
            } else {
                upperIndex = middleIndex
            }
        }

        let lowerPoint = trend[lowerIndex]
        let upperPoint = trend[upperIndex]
        let interval = upperPoint.startTimestamp.timeIntervalSince(lowerPoint.startTimestamp)
        guard interval > 0 else { return lowerPoint.averagePrice }

        let progress = timestamp.timeIntervalSince(lowerPoint.startTimestamp) / interval
        return lowerPoint.averagePrice
            + (upperPoint.averagePrice - lowerPoint.averagePrice) * progress
    }
}

private struct PriceHistoryContent: View {
    let history: PriceStatisticsData
    let chartTrend: [PriceStatisticsData.TrendPoint]
    let range: PriceHistoryRange

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PriceHistorySummaryCard(
                    sample: history,
                    comparisonLabel: range.comparisonLabel,
                    showsComparison: range != .twoYears
                )
                PriceHistoryTrendCard(sample: history, trend: chartTrend, range: range)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ],
                    spacing: 10
                ) {
                    PriceHistoryMetricTile(
                        title: "Lowest price",
                        value: historyPriceText(history.lowest.price),
                        detail: historyDateText(history.lowest.timestamp),
                        systemImage: "arrow.down",
                        tint: AppTheme.success
                    )
                    PriceHistoryMetricTile(
                        title: "Highest price",
                        value: historyPriceText(history.highest.price),
                        detail: historyDateText(history.highest.timestamp),
                        systemImage: "arrow.up",
                        tint: AppTheme.error
                    )
                    PriceHistoryMetricTile(
                        title: "Negative prices",
                        value: historyHoursText(history.negativeHours),
                        detail: "Total duration".localized(),
                        systemImage: "minus.circle.fill",
                        tint: AppTheme.success
                    )
                    PriceHistoryMetricTile(
                        title: "Below average",
                        value: (history.belowAveragePercent / 100).formatted(
                            .percent.precision(.fractionLength(0))
                        ),
                        detail: "Of all intervals".localized(),
                        systemImage: "chart.bar.fill",
                        tint: AppTheme.accent
                    )
                }

                PriceHistoryDistributionCard(distribution: history.distribution)
                PriceHistoryHighlightCard(sample: history)

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.easeInOut(duration: 0.25), value: range)
        }
    }
}

private struct PriceHistorySummaryCard: View {
    let sample: PriceStatisticsData
    let comparisonLabel: String
    let showsComparison: Bool

    private var changeTint: Color {
        (sample.comparisonChangePercent ?? 0) <= 0 ? AppTheme.success : AppTheme.error
    }

    private var changeIcon: String {
        (sample.comparisonChangePercent ?? 0) <= 0 ? "arrow.down.right" : "arrow.up.right"
    }

    private var changeText: String {
        let percentage = (abs(sample.comparisonChangePercent ?? 0) / 100)
            .formatted(.percent.precision(.fractionLength(1)))
        let format = (sample.comparisonChangePercent ?? 0) <= 0 ? "%@ lower".localized() : "%@ higher".localized()
        return String(format: format, percentage)
    }

    var body: some View {
        InsightsCard(tint: AppTheme.accent) {
            Text("Average price")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(historyPriceText(sample.averagePrice, includesUnit: false))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("ct/kWh")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if showsComparison, sample.comparisonChangePercent != nil {
                HStack(spacing: 6) {
                    Label(changeText, systemImage: changeIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(changeTint)

                    Text(String(format: "than %@".localized(), comparisonLabel.localized()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PriceHistoryTrendCard: View {
    let sample: PriceStatisticsData
    let trend: [PriceStatisticsData.TrendPoint]
    let range: PriceHistoryRange

    private var chartTimeDomain: ClosedRange<Date> {
        guard let first = sample.trend.first?.startTimestamp,
              let last = trend.last?.startTimestamp else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }

        let edgePadding: TimeInterval = 12 * 60 * 60
        return first.addingTimeInterval(-edgePadding)...last.addingTimeInterval(edgePadding)
    }

    private var chartDomain: ClosedRange<Double> {
        let values = trend
            .filter { chartTimeDomain.contains($0.startTimestamp) }
            .map(\.averagePrice)
        let lower = max(0, (values.min() ?? 0) - 5)
        let upper = max(lower + 1, (values.max() ?? 50) + 5)
        return lower...upper
    }

    var body: some View {
        InsightsCard(tint: AppTheme.accent) {
            Label("Price trend", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(.primary)

            Chart(trend) { point in
                AreaMark(
                    x: .value("Date", point.startTimestamp),
                    yStart: .value("Chart minimum", chartDomain.lowerBound),
                    yEnd: .value("Price", point.averagePrice)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.28), AppTheme.accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.startTimestamp),
                    y: .value("Price", point.averagePrice)
                )
                .foregroundStyle(AppTheme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXScale(domain: chartTimeDomain)
            .chartYScale(domain: chartDomain)
            .chartPlotStyle { plotArea in
                plotArea
                    .clipShape(Rectangle())
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.35))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.12))
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text(historyPriceText(price, includesUnit: false))
                                .font(.caption2)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.55), value: range)
            .frame(height: 190)
            .accessibilityLabel(Text("Historic average price trend"))
        }
    }
}

private struct PriceHistoryMetricTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)

                Text(title.localized())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .appCardStyle(cornerRadius: 16, padding: 0)
    }
}

private struct PriceHistoryDistributionCard: View {
    let distribution: PriceStatisticsData.Distribution

    var body: some View {
        InsightsCard(tint: AppTheme.accent) {
            Text("Price distribution")
                .font(.headline)

            GeometryReader { geometry in
                let spacing: CGFloat = 3
                let width = max(geometry.size.width - spacing * 2, 0)

                HStack(spacing: spacing) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.success)
                        .frame(width: width * distribution.cheapPercent / 100)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.accent)
                        .frame(width: width * distribution.typicalPercent / 100)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.error)
                        .frame(width: width * distribution.expensivePercent / 100)
                }
            }
            .frame(height: 18)

            HStack(spacing: 0) {
                PriceDistributionLabel(
                    title: "Cheap",
                    value: distribution.cheapPercent,
                    priceRange: "< \(historyPriceText(distribution.cheapBelow))",
                    tint: AppTheme.success
                )
                Spacer()
                PriceDistributionLabel(
                    title: "Typical",
                    value: distribution.typicalPercent,
                    priceRange: "\(historyPriceText(distribution.cheapBelow))–\(historyPriceText(distribution.expensiveAbove))",
                    tint: AppTheme.accent
                )
                Spacer()
                PriceDistributionLabel(
                    title: "Expensive",
                    value: distribution.expensivePercent,
                    priceRange: "> \(historyPriceText(distribution.expensiveAbove))",
                    tint: AppTheme.error
                )
            }
        }
    }
}

private struct PriceDistributionLabel: View {
    let title: String
    let value: Double
    let priceRange: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)

                Text(title.localized())
                    .font(.caption.weight(.semibold))
            }

            Text("\((value / 100).formatted(.percent.precision(.fractionLength(0)))) · \(priceRange)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct PriceHistoryHighlightCard: View {
    let sample: PriceStatisticsData

    var body: some View {
        InsightsCard(tint: AppTheme.success) {
            Label(sample.highlightTitle.localized(), systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline) {
                Text(sample.highlightValue)
                    .font(.title2.weight(.bold))

                Spacer()

                Text(
                    String(
                        format: "%@ average".localized(),
                        historyPriceText(sample.highlight.averagePrice)
                    )
                )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.success)
                    .monospacedDigit()
            }
        }
    }
}

private func historyDateText(_ date: Date) -> String {
    let dateText = date.formatted(date: .abbreviated, time: .omitted)
    let timeText = date.formatted(date: .omitted, time: .shortened)
    return "\(dateText) · \(timeText)"
}

private func historyHoursText(_ hours: Double) -> String {
    let roundedHours = hours.rounded()
    if abs(hours - roundedHours) < 0.01 {
        return "\(Int(roundedHours))h"
    }
    return "\(hours.formatted(.number.precision(.fractionLength(1))))h"
}

private func historyPriceText(_ price: Double, includesUnit: Bool = true) -> String {
    let number = price.priceString.flatMap { $0.isEmpty ? nil : $0 } ?? "0.00"
    return includesUnit ? "\(number) ct" : number
}

#Preview {
    NavigationStack {
        PriceHistoryView(previewData: .preview)
    }
    .environmentObject(SettingsManager.shared)
}

private extension PriceStatisticsData {
    static var preview: PriceStatisticsData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let trend = [29.6, 31.4, 27.8, 24.2, 22.6, 25.1, 28.0, 23.4, 20.9, 24.7]
            .enumerated()
            .map { index, value in
                TrendPoint(
                    startTimestamp: calendar.date(byAdding: .day, value: index - 9, to: today) ?? today,
                    averagePrice: value
                )
            }
        return PriceStatisticsData(
            averagePrice: 24.10,
            comparisonChangePercent: -7.8,
            lowest: Extremum(price: -3.72, timestamp: today.addingTimeInterval(-7 * 86_400)),
            highest: Extremum(price: 68.44, timestamp: today.addingTimeInterval(-18 * 86_400)),
            negativeHours: 11,
            belowAveragePercent: 58,
            distribution: Distribution(
                cheapPercent: 38,
                typicalPercent: 44,
                expensivePercent: 18,
                cheapBelow: 20,
                expensiveAbove: 35
            ),
            trend: trend,
            highlight: Highlight(kind: "weekday", timestamp: nil, value: 7, averagePrice: 19.80),
            coverage: Coverage(percent: 100, isComplete: true, isUsable: true)
        )
    }
}
