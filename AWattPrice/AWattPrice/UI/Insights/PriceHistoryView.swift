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

    /// Names the period itself, for phrases like "12% below <periodLabel> average".
    var periodLabel: String {
        switch self {
        case .month: "this month's"
        case .quarter: "this quarter's"
        case .year: "this year's"
        case .twoYears: "these two years'"
        }
    }

    /// What consecutive trend buckets represent for this range, for the "typical swing" tile.
    var swingLabel: String {
        switch self {
        case .month: "Between days"
        case .quarter: "Between weeks"
        case .year, .twoYears: "Between months"
        }
    }
}

private extension PriceStatisticsData {
    /// Average absolute change between consecutive trend buckets. Unlike a mean-based
    /// percentage, this isn't distorted by distribution skew — a period with a few wild
    /// spikes or dips should read as more volatile, and this number goes up exactly because
    /// of that, rather than being pulled around by where the mean happens to sit.
    var typicalSwing: Double? {
        let sorted = trend.sorted { $0.startTimestamp < $1.startTimestamp }
        guard sorted.count > 1 else { return nil }
        let diffs = zip(sorted, sorted.dropFirst()).map { abs($1.averagePrice - $0.averagePrice) }
        return diffs.reduce(0, +) / Double(diffs.count)
    }
}

private enum PriceHistoryFailureReason: Equatable {
    case network
    case insufficientData
}

private enum PriceHistoryLoadState {
    case loading
    case loaded([PriceHistoryRange: PriceStatisticsData])
    case failed(PriceHistoryFailureReason)
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
    @EnvironmentObject private var energyDataService: EnergyDataService
    @State private var selectedRange: PriceHistoryRange = .month
    @State private var loadState: PriceHistoryLoadState
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
                            range: selectedRange,
                            liveComparisonPercent: liveComparisonPercent(for: history)
                        )
                            .transition(.opacity)
                    } else {
                        unavailableView(reason: .insufficientData)
                    }
                case .failed(let reason):
                    unavailableView(reason: reason)
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

    private func unavailableView(reason: PriceHistoryFailureReason) -> some View {
        VStack(spacing: 14) {
            Image(systemName: reason == .network ? "wifi.slash" : "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)
            Text((reason == .network ? "Price history unavailable" : "Not enough history yet").localized())
                .font(.headline)
            Text(
                (
                    reason == .network
                        ? "Check your connection and try again."
                        : "We don't have enough price data for this market area and range yet. Check back later."
                ).localized()
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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

        let requestKey = requestKey
        if let cache = energyDataService.priceStatisticsCache, cache.isValid(for: requestKey) {
            loadState = decodeRanges(from: cache.histories)
            return
        }

        loadState = .loading
        let setting = settingsManager.setting

        do {
            let response = try await PriceStatisticsData.download(
                marketArea: setting.marketArea,
                pricingConfiguration: setting.pricingConfiguration
            )
            guard Task.isCancelled == false else { return }

            energyDataService.priceStatisticsCache = PriceStatisticsCache(
                requestKey: requestKey,
                cachedAt: Date(),
                histories: response
            )
            loadState = decodeRanges(from: response)
        } catch is CancellationError {
            return
        } catch {
            print("Price history download failed: \(error).")
            loadState = .failed(.network)
        }
    }

    private func decodeRanges(from response: [String: PriceStatisticsData]) -> PriceHistoryLoadState {
        let histories: [PriceHistoryRange: PriceStatisticsData] = response.reduce(into: [:]) { result, entry in
            guard let range = PriceHistoryRange(rawValue: entry.key), entry.value.coverage.isUsable else {
                return
            }
            result[range] = entry.value
        }
        return histories.isEmpty ? .failed(.insufficientData) : .loaded(histories)
    }

    /// Compares the currently active price (already includes the user's add-ons, same as `history.averagePrice`)
    /// against the selected period's average, as a percentage (negative = currently cheaper than usual).
    private func liveComparisonPercent(for history: PriceStatisticsData) -> Double? {
        guard history.averagePrice != 0,
              let currentPrice = energyDataService.energyData?.currentPrices.first(where: { $0.startTime <= Date() && $0.endTime > Date() })
                ?? energyDataService.energyData?.currentPrices.first
        else {
            return nil
        }
        return (currentPrice.marketprice - history.averagePrice) / abs(history.averagePrice) * 100
    }

    private func chartTrend(
        from histories: [PriceHistoryRange: PriceStatisticsData],
        for selectedRange: PriceHistoryRange
    ) -> [PriceStatisticsData.TrendPoint] {
        guard let selectedTrend = histories[selectedRange]?.trend,
              let selectedStart = selectedTrend.first?.startTimestamp,
              let fallbackTrend = PriceHistoryRange.allCases.reversed()
                .compactMap({ histories[$0]?.trend })
                .first(where: { $0.isEmpty == false }) else {
            return []
        }

        let timestamps = Set(
            histories.values.flatMap { history in
                history.trend.map(\.startTimestamp)
            }
        )
        guard let latestTimestamp = timestamps.max() else { return [] }
        let selectedTrendForChart = trend(
            selectedTrend,
            endingAt: latestTimestamp
        )

        return timestamps.sorted().compactMap { timestamp in
            let sourceTrend = timestamp >= selectedStart ? selectedTrendForChart : fallbackTrend
            guard let averagePrice = smoothlyInterpolatedAverage(at: timestamp, in: sourceTrend) else {
                return nil
            }
            return PriceStatisticsData.TrendPoint(
                startTimestamp: timestamp,
                averagePrice: averagePrice
            )
        }
    }

    private func trend(
        _ trend: [PriceStatisticsData.TrendPoint],
        endingAt latestTimestamp: Date
    ) -> [PriceStatisticsData.TrendPoint] {
        guard trend.count > 1,
              let last = trend.last,
              last.startTimestamp < latestTimestamp else {
            return trend
        }

        return Array(trend.dropLast()) + [
            PriceStatisticsData.TrendPoint(
                startTimestamp: latestTimestamp,
                averagePrice: last.averagePrice
            )
        ]
    }

    private func smoothlyInterpolatedAverage(
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

        let lower = trend[lowerIndex]
        let upper = trend[upperIndex]
        let interval = upper.startTimestamp.timeIntervalSince(lower.startTimestamp)
        guard interval > 0 else { return lower.averagePrice }

        let previous = lowerIndex > 0 ? trend[lowerIndex - 1] : lower
        let next = upperIndex + 1 < trend.count ? trend[upperIndex + 1] : upper
        let lowerSlopeInterval = upper.startTimestamp.timeIntervalSince(previous.startTimestamp)
        let upperSlopeInterval = next.startTimestamp.timeIntervalSince(lower.startTimestamp)
        let segmentSlope = (upper.averagePrice - lower.averagePrice) / interval
        let lowerSlope = lowerSlopeInterval > 0
            ? (upper.averagePrice - previous.averagePrice) / lowerSlopeInterval
            : segmentSlope
        let upperSlope = upperSlopeInterval > 0
            ? (next.averagePrice - lower.averagePrice) / upperSlopeInterval
            : segmentSlope

        let progress = timestamp.timeIntervalSince(lower.startTimestamp) / interval
        let progressSquared = progress * progress
        let progressCubed = progressSquared * progress
        let lowerWeight = 2 * progressCubed - 3 * progressSquared + 1
        let lowerSlopeWeight = progressCubed - 2 * progressSquared + progress
        let upperWeight = -2 * progressCubed + 3 * progressSquared
        let upperSlopeWeight = progressCubed - progressSquared

        return lowerWeight * lower.averagePrice
            + lowerSlopeWeight * interval * lowerSlope
            + upperWeight * upper.averagePrice
            + upperSlopeWeight * interval * upperSlope
    }
}

private struct PriceHistoryContent: View {
    let history: PriceStatisticsData
    let chartTrend: [PriceStatisticsData.TrendPoint]
    let range: PriceHistoryRange
    let liveComparisonPercent: Double?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PriceHistorySummaryCard(
                    sample: history,
                    comparisonLabel: range.comparisonLabel,
                    showsComparison: range != .twoYears,
                    liveComparisonPercent: liveComparisonPercent,
                    periodLabel: range.periodLabel
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
                    if let swing = history.typicalSwing {
                        PriceHistoryMetricTile(
                            title: "Typical swing",
                            value: historyPriceText(swing),
                            detail: range.swingLabel.localized(),
                            systemImage: "arrow.up.arrow.down",
                            tint: AppTheme.accent
                        )
                    }
                }

                PriceHistoryWeekdayPatternCard(pattern: history.weekdayHourPattern)
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
    let liveComparisonPercent: Double?
    let periodLabel: String

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

    private var liveTint: Color {
        (liveComparisonPercent ?? 0) <= 0 ? AppTheme.success : AppTheme.error
    }

    private var liveText: String {
        let percentage = (abs(liveComparisonPercent ?? 0) / 100)
            .formatted(.percent.precision(.fractionLength(0)))
        let format = (liveComparisonPercent ?? 0) <= 0
            ? "Right now: %@ below %@ average".localized()
            : "Right now: %@ above %@ average".localized()
        return String(format: format, percentage, periodLabel.localized())
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

            if let liveComparisonPercent {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(liveTint)
                    Text(liveText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
                .accessibilityElement(children: .combine)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: liveComparisonPercent)
    }
}

private struct PriceHistoryTrendCard: View {
    let sample: PriceStatisticsData
    let trend: [PriceStatisticsData.TrendPoint]
    let range: PriceHistoryRange
    @State private var selectedTimestamp: Date?

    private var visibleTrend: [PriceStatisticsData.TrendPoint] {
        guard let first = sample.trend.first?.startTimestamp else { return trend }
        return trend.filter { $0.startTimestamp >= first }
    }

    private func chartPosition(
        for point: PriceStatisticsData.TrendPoint
    ) -> (timestamp: Date, averagePrice: Double) {
        guard let first = visibleTrend.first,
              point.startTimestamp < first.startTimestamp else {
            return (point.startTimestamp, point.averagePrice)
        }
        return (first.startTimestamp, first.averagePrice)
    }

    private var selectedPoint: PriceStatisticsData.TrendPoint? {
        guard let selectedTimestamp else { return nil }
        guard let selectedBucket = sample.trend.min(by: {
            abs($0.startTimestamp.timeIntervalSince(selectedTimestamp))
                < abs($1.startTimestamp.timeIntervalSince(selectedTimestamp))
        }) else { return nil }
        return trend.first { $0.startTimestamp == selectedBucket.startTimestamp } ?? selectedBucket
    }

    private func selectedDateText(for point: PriceStatisticsData.TrendPoint) -> String {
        point.startTimestamp.formatted(date: .numeric, time: .omitted)
    }

    private var chartTimeDomain: ClosedRange<Date> {
        guard let first = sample.trend.first?.startTimestamp,
              let last = visibleTrend.last?.startTimestamp else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }

        let edgePadding: TimeInterval = 12 * 60 * 60
        return first.addingTimeInterval(-edgePadding)...last.addingTimeInterval(edgePadding)
    }

    private var chartDomain: ClosedRange<Double> {
        let values = visibleTrend.map(\.averagePrice)
        let lower = max(0, (values.min() ?? 0) - 5)
        let upper = max(lower + 1, (values.max() ?? 50) + 5)
        return lower...upper
    }

    private var axisDates: [Date] {
        let calendar = Calendar.autoupdatingCurrent
        guard let first = sample.trend.first?.startTimestamp,
              let last = visibleTrend.last?.startTimestamp else {
            return []
        }

        if range == .month {
            return (0..<4).compactMap { week in
                calendar.date(byAdding: .day, value: week * 7, to: first)
            }.filter { $0 <= last }
        }

        let lowerBound = range == .quarter ? first : chartTimeDomain.lowerBound
        let upperBound = range == .quarter ? last : chartTimeDomain.upperBound
        guard var month = calendar.dateInterval(of: .month, for: lowerBound)?.start else {
            return []
        }

        var dates: [Date] = []
        while month <= upperBound {
            let isInsideRange = month >= lowerBound
            let monthNumber = calendar.component(.month, from: month)
            let matchesInterval = switch range {
            case .quarter: true
            case .year: (monthNumber - 1).isMultiple(of: 2)
            case .twoYears: (monthNumber - 1).isMultiple(of: 4)
            case .month: false
            }
            if isInsideRange && matchesInterval {
                dates.append(month)
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else {
                break
            }
            month = nextMonth
        }
        return dates
    }

    private func axisLabel(for date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        switch range {
        case .month:
            return date.formatted(.dateTime.day().month(.abbreviated))
        case .quarter:
            return date.formatted(.dateTime.month(.wide))
        case .year, .twoYears:
            if calendar.component(.month, from: date) == 1 {
                return String(calendar.component(.year, from: date))
            }
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    var body: some View {
        InsightsCard(tint: AppTheme.accent) {
            HStack(spacing: 8) {
                Label("Price trend", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                if let selectedPoint {
                    Text("\(selectedDateText(for: selectedPoint)) · \(historyPriceText(selectedPoint.averagePrice))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.14), value: selectedPoint?.startTimestamp)

            Chart {
                ForEach(trend, id: \.startTimestamp) { point in
                    let position = chartPosition(for: point)
                    AreaMark(
                        x: .value("Date", position.timestamp),
                        yStart: .value("Chart minimum", chartDomain.lowerBound),
                        yEnd: .value("Price", position.averagePrice)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.28), AppTheme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", position.timestamp),
                        y: .value("Price", position.averagePrice)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let selectedPoint {
                    RuleMark(x: .value("Selected date", selectedPoint.startTimestamp))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    PointMark(
                        x: .value("Selected date", selectedPoint.startTimestamp),
                        y: .value("Selected average", selectedPoint.averagePrice)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .symbolSize(54)
                }
            }
            .chartXScale(domain: chartTimeDomain)
            .chartYScale(domain: chartDomain)
            .chartPlotStyle { plotArea in
                plotArea
                    .clipShape(Rectangle())
            }
            .chartXAxis {
                AxisMarks(values: axisDates) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(axisLabel(for: date))
                                .font(.caption2)
                        }
                    }
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
                            Text(price.formatted(.number.precision(.fractionLength(0))))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrameAnchor = proxy.plotFrame else { return }
                                    let plotFrame = geometry[plotFrameAnchor]
                                    let xPosition = min(
                                        max(value.location.x - plotFrame.origin.x, 0),
                                        plotFrame.width
                                    )
                                    withAnimation(.easeOut(duration: 0.16)) {
                                        selectedTimestamp = proxy.value(atX: xPosition)
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.14)) {
                                        selectedTimestamp = nil
                                    }
                                }
                        )
                }
            }
            .animation(.easeInOut(duration: 0.55), value: range)
            .animation(.easeOut(duration: 0.16), value: selectedPoint?.startTimestamp)
            .frame(height: 190)
            .accessibilityLabel(Text("Historic average price trend"))
        }
        .onChange(of: range) {
            selectedTimestamp = nil
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

/// Weekday x time-of-day price pattern, computed by the backend from this market area's own
/// price history (`weekday_hour_pattern`) — real per-user data, not an illustration.
private struct PriceHistoryWeekdayPatternCard: View {
    let pattern: [PriceStatisticsData.WeekdayHourAveragePrice]

    private static let hourLabels = ["0", "4", "8", "12", "16", "20"]
    private static let weekdayLabels = DateFormatter().shortWeekdaySymbols
        ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let weekdayLabelWidth: CGFloat = 30

    /// 7 (Sunday-first) x 6 (4-hour bucket) grid of average prices, or nil where no data exists.
    private var bucketedAverages: [[Double?]] {
        var byWeekdayHour: [Int: [Int: Double]] = [:]
        for entry in pattern {
            byWeekdayHour[entry.weekday, default: [:]][entry.hour] = entry.averagePrice
        }
        return (0..<7).map { row in
            // Sunday-first row order (row 0 = Sun) to ISO weekday (Sun = 7).
            let isoWeekday = row == 0 ? 7 : row
            let hourly = byWeekdayHour[isoWeekday] ?? [:]
            return stride(from: 0, to: 24, by: 4).map { bucketStart in
                let values = (bucketStart..<(bucketStart + 4)).compactMap { hourly[$0] }
                return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            }
        }
    }

    /// The same grid, normalized to 0 (cheapest) ... 1 (priciest) across the whole pattern.
    private var normalizedMatrix: [[Double?]] {
        let buckets = bucketedAverages
        let allValues = buckets.flatMap { $0.compactMap { $0 } }
        guard let minValue = allValues.min(), let maxValue = allValues.max(), maxValue > minValue else {
            return buckets.map { $0.map { $0 == nil ? nil : 0.5 } }
        }
        return buckets.map { row in
            row.map { value in
                value.map { ($0 - minValue) / (maxValue - minValue) }
            }
        }
    }

    private func color(for value: Double?) -> Color {
        guard let value else { return Color.secondary.opacity(0.08) }
        let palette: [Color] = [
            AppTheme.success.opacity(0.85),
            AppTheme.success.opacity(0.4),
            Color.secondary.opacity(0.15),
            AppTheme.error.opacity(0.4),
            AppTheme.error.opacity(0.85),
        ]
        let index = min(max(Int(value * Double(palette.count)), 0), palette.count - 1)
        return palette[index]
    }

    var body: some View {
        InsightsCard(tint: AppTheme.accent) {
            Label("Typical price pattern".localized(), systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Based on this market area's own price history for the selected period.".localized())
                .font(.caption2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Color.clear.frame(width: Self.weekdayLabelWidth, height: 1)
                    ForEach(Self.hourLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                let matrix = normalizedMatrix
                ForEach(Self.weekdayLabels.indices, id: \.self) { row in
                    HStack(spacing: 4) {
                        Text(Self.weekdayLabels[row])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: Self.weekdayLabelWidth, alignment: .leading)

                        ForEach(matrix[row].indices, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color(for: matrix[row][column]))
                                .frame(height: 18)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Cheaper".localized())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                LinearGradient(
                    colors: [AppTheme.success.opacity(0.85), Color.secondary.opacity(0.15), AppTheme.error.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
                .clipShape(Capsule())
                Text("More expensive".localized())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
    .environmentObject(EnergyDataService())
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
        let weekdayHourPattern = (1...7).flatMap { weekday in
            (0..<24).map { hour -> WeekdayHourAveragePrice in
                let base = weekday >= 6 ? 18.0 : 24.0
                let hourOffset: Double = switch hour {
                case 11...14: -8
                case 6...7, 17...19: 10
                default: 0
                }
                return WeekdayHourAveragePrice(weekday: weekday, hour: hour, averagePrice: base + hourOffset)
            }
        }
        return PriceStatisticsData(
            averagePrice: 24.10,
            comparisonChangePercent: -7.8,
            lowest: Extremum(price: -3.72, timestamp: today.addingTimeInterval(-7 * 86_400)),
            highest: Extremum(price: 68.44, timestamp: today.addingTimeInterval(-18 * 86_400)),
            negativeHours: 11,
            belowAveragePercent: 58,
            trend: trend,
            weekdayHourPattern: weekdayHourPattern,
            highlight: Highlight(kind: "weekday", timestamp: nil, value: 7, averagePrice: 19.80),
            coverage: Coverage(percent: 100, isComplete: true, isUsable: true)
        )
    }
}
