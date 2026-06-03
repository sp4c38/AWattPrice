//
//  GenerationMixHistoryView.swift
//  AWattPrice
//
//  Created by Codex on 25.05.26.
//

import SwiftUI
import Charts

private enum GenerationMixHistoryLoadState {
    case loading
    case loaded(GenerationMixHistoryData)
    case failed
}

struct GenerationMixHistoryView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var settingsManager: SettingsManager

    private var marketArea: MarketArea {
        settingsManager.setting.marketArea
    }

    @State private var selectedRange: GenerationMixHistoryRange = .day
    @State private var loadState: GenerationMixHistoryLoadState = .loading

    // Only re-trigger the load task when the market area changes.
    // Range changes are handled purely in-memory from the cached 7d dataset.
    private var requestKey: String {
        marketArea.key
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Range", selection: $selectedRange) {
                ForEach(GenerationMixHistoryRange.allCases) { range in
                    Text(range.title)
                        .tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Group {
                switch loadState {
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.success)

                        Text("Loading generation mix")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let history):
                    GenerationMixHistoryContent(history: history, range: selectedRange)
                case .failed:
                    VStack(spacing: 14) {
                        Image(systemName: "leaf")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.success)

                        Text("Generation mix unavailable")
                            .font(.headline)

                        Button("Try Again") {
                            Task { await loadHistory() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .appScreenBackground()
        .navigationTitle("Energy Mix")
        .navigationBarTitleDisplayMode(.large)
        .task(id: requestKey) {
            await loadHistory()
        }
    }

    private func loadHistory() async {
        // If the service already has the 7d dataset (fetched during the main
        // data refresh, or from a previous visit to this screen), use it
        // immediately — no network call needed.
        if let cached = energyDataService.generationMixHistoryData {
            loadState = .loaded(cached)
            return
        }

        loadState = .loading

        do {
            let history = try await GenerationMixHistoryData.download(marketArea: marketArea, range: .week)
            energyDataService.generationMixHistoryData = history
            loadState = .loaded(history)
        } catch {
            print("Generation mix history download failed: \(error).")
            if case .loading = loadState {
                loadState = .failed
            }
        }
    }
}

private struct GenerationMixHistoryContent: View {
    let history: GenerationMixHistoryData
    let range: GenerationMixHistoryRange

    // The selected interval lives inside GenerationMixStackedGenerationChart so
    // this view does not re-render on every drag event — both interval arrays are
    // computed once per range switch, which keeps the chart animation in sync.
    // The chart writes back only this single boolean, and only when it actually
    // flips (the user's selection crosses a preliminary/complete boundary), so
    // those re-renders are rare and carry identical interval data.
    @State private var selectedIntervalIsPartial = false
    // Selection intervals keep the last clock-hour at native resolution so the
    // breakdown matches the live InsightsView reading.
    private var displayIntervals: [GenerationMixInterval] {
        generationMixDisplayIntervals(for: history, range: range, nativeLastHour: true)
    }

    // Rendering intervals are purely hourly so the smoothing algorithm (which
    // is index-based, not time-based) doesn't produce a bump where native
    // 15-min points suddenly follow hour-averaged points.
    private var allDisplayIntervals: [GenerationMixInterval] {
        generationMixDisplayIntervals(for: history, range: .week, nativeLastHour: false)
    }

    private var displayRenewableShare: Double {
        let intervals = displayIntervals
        let totalRenewable = intervals.reduce(0.0) { $0 + $1.renewableGenerationMW }
        let totalGeneration = intervals.reduce(0.0) { $0 + $1.totalGenerationMW }
        return totalGeneration > 0 ? (totalRenewable / totalGeneration) * 100 : 0
    }

    private var hasPartialPublicationIntervals: Bool {
        displayIntervals.contains { $0.isPartialPublication }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InsightsCard(tint: AppTheme.success) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(percentText(displayRenewableShare))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text("renewable")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: range)

                InsightsCard(tint: AppTheme.success) {
                    GenerationMixStackedGenerationChart(
                        history: history,
                        allIntervals: allDisplayIntervals,
                        intervals: displayIntervals,
                        range: range,
                        selectedIntervalIsPartial: $selectedIntervalIsPartial
                    )
                }

                if hasPartialPublicationIntervals {
                    GenerationMixPartialPublicationNote(prominent: selectedIntervalIsPartial)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private func generationMixDisplayIntervals(
    for history: GenerationMixHistoryData,
    range: GenerationMixHistoryRange,
    nativeLastHour: Bool
) -> [GenerationMixInterval] {
    // Trim to the requested window.  The cached dataset is always 7d so 24h
    // and 3d are derived in-memory without any extra network traffic.
    let cutoff = history.endTime.addingTimeInterval(-TimeInterval(range.hours) * 3600)
    let trimmed = history.sortedIntervals.filter { $0.startTime >= cutoff }
    guard trimmed.isEmpty == false else { return [] }

    // Group by calendar clock-hours rather than offsets from firstStartTime.
    // Clock-hour alignment guarantees the last bucket is always the current,
    // still-filling clock hour — regardless of which range (24h / 3d / 7d) is
    // selected.  Offset-relative bucketing causes the 24h range to produce a
    // "full" last bucket whose intervals straddle the live period, making the
    // displayed values diverge from the Insights view.
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: trimmed) { interval in
        calendar.dateInterval(of: .hour, for: interval.startTime)?.start ?? interval.startTime
    }

    let sortedBucketKeys = grouped.keys.sorted()
    let lastBucketKey = sortedBucketKeys.last

    return sortedBucketKeys.flatMap { bucketStart -> [GenerationMixInterval] in
        guard let bucket = grouped[bucketStart], bucket.isEmpty == false else { return [] }

        // Selection data: keep the last clock-hour at native resolution so the
        // breakdown matches the live Insights view.
        if nativeLastHour && bucketStart == lastBucketKey {
            return bucket.sorted { $0.startTime < $1.startTime }
        }

        // Rendering data: always produce one averaged point per bucket so point
        // density stays uniform and the index-based smoother doesn't create a
        // bump. For the last bucket, anchor the point at the most recent
        // interval's start time so the chart visually extends to the latest data.
        let startTime = (bucketStart == lastBucketKey)
            ? (bucket.map(\.startTime).max() ?? bucketStart)
            : bucketStart

        return [averagedGenerationMixInterval(
            from: bucket,
            categories: history.categories,
            startTime: startTime
        )]
    }
}

private func averagedGenerationMixInterval(
    from intervals: [GenerationMixInterval],
    categories: [GenerationMixCategory],
    startTime: Date
) -> GenerationMixInterval {
    let divisor = Double(max(intervals.count, 1))
    let endTime = intervals.map(\.endTime).max() ?? startTime.addingTimeInterval(60 * 60)
    let averagedCategories = categories.map { category in
        let generationMW = intervals.reduce(0) { total, interval in
            total + (interval.categories.first { $0.category == category.category }?.generationMW ?? 0)
        } / divisor
        return GenerationMixCategory(
            category: category.category,
            generationMW: generationMW,
            share: 0,
            isRenewable: category.isRenewable
        )
    }
    let totalGenerationMW = averagedCategories.reduce(0) { $0 + $1.generationMW }
    let renewableGenerationMW = averagedCategories
        .filter { $0.isRenewable }
        .reduce(0) { $0 + $1.generationMW }
    let finalCategories = averagedCategories.map { category in
        GenerationMixCategory(
            category: category.category,
            generationMW: category.generationMW,
            share: totalGenerationMW > 0 ? (category.generationMW / totalGenerationMW) * 100 : 0,
            isRenewable: category.isRenewable
        )
    }

    return GenerationMixInterval(
        startTime: startTime,
        endTime: endTime,
        totalGenerationMW: totalGenerationMW,
        renewableGenerationMW: renewableGenerationMW,
        renewableShare: totalGenerationMW > 0 ? (renewableGenerationMW / totalGenerationMW) * 100 : 0,
        categories: finalCategories,
        isPartialPublication: intervals.contains { $0.isPartialPublication }
    )
}

private struct GenerationMixPartialPublicationNote: View {
    // Raised slightly when the user's selection lands on a preliminary interval,
    // so the explanation is more noticeable right when it's relevant — without
    // becoming an alarming warning.
    var prominent: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: prominent ? "info.circle.fill" : "info.circle")
                .font(.caption)
                .foregroundStyle(prominent ? .primary : .secondary)
                .frame(width: 16)

            Text("Some generation data for today has not been reported yet.")
                .font(.caption)
                .fontWeight(prominent ? .medium : .regular)
                .foregroundStyle(prominent ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(prominent ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: prominent)
    }
}

private struct GenerationMixSelectedIntervalView: View {
    let interval: GenerationMixInterval

    private var topCategories: [GenerationMixCategory] {
        interval.visibleCategories
    }

    private var animationKey: String {
        "\(interval.startTime.timeIntervalSince1970)-\(Int(interval.totalGenerationMW.rounded()))-\(Int(interval.renewableShare.rounded()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeRangeText(from: interval.startTime, to: interval.endTime))
                        .font(.subheadline.weight(.semibold))

                    Text(megawattText(interval.totalGenerationMW))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(percentText(interval.renewableShare))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("renewable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GenerationMixBar(categories: interval.visibleCategories)

            FlowLayout(horizontalSpacing: 14, verticalSpacing: 8) {
                ForEach(topCategories) { category in
                    GenerationMixCategoryLabel(category: category, showsMW: true)
                }
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(historyIntervalAccessibilityText(interval))
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.86, blendDuration: 0.06), value: animationKey)
    }
}

private struct GenerationMixChartPoint: Identifiable {
    let id: String
    let time: Date
    let category: String
    let generationMW: Double
}

private struct GenerationMixTotalChartPoint: Identifiable {
    let id: Date
    let time: Date
    let generationMW: Double
}

private struct GenerationMixStackedGenerationChart: View {
    let history: GenerationMixHistoryData
    let allIntervals: [GenerationMixInterval]  // full 7d — stable across range switches
    let intervals: [GenerationMixInterval]     // range-filtered — for domain & selection
    let range: GenerationMixHistoryRange

    // Mirrors whether the current selection sits on a preliminary interval. Owned
    // by the parent so the explanatory note can react, but written only on flips.
    @Binding var selectedIntervalIsPartial: Bool

    @Environment(\.colorScheme) private var colorScheme

    // Owned here so drag events only re-render this view, not the parent.
    @State private var selectedIntervalID: Date?

    private var chartPoints: [GenerationMixChartPoint] {
        smoothedCategoryValues.flatMap { entry in
            entry.values.map { value in
                return GenerationMixChartPoint(
                    id: "\(value.time.timeIntervalSince1970)-\(entry.category)",
                    time: value.time,
                    category: entry.category,
                    generationMW: value.generationMW
                )
            }
        }
    }

    private var totalPoints: [GenerationMixTotalChartPoint] {
        smoothedTotals.map { value in
            GenerationMixTotalChartPoint(
                id: value.time,
                time: value.time,
                generationMW: value.generationMW
            )
        }
    }

    private var categoryDomain: [String] {
        history.orderedCategories.map(\.category)
    }

    private var categoryColors: [Color] {
        categoryDomain.map(generationMixColor)
    }

    private var partialIntervals: [GenerationMixInterval] {
        intervals.filter { $0.isPartialPublication }
    }

    private var edgePaddingDuration: TimeInterval {
        guard let first = allIntervals.first else { return 60 * 60 }
        return max(first.endTime.timeIntervalSince(first.startTime), 60 * 60) * 0.5
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = intervals.first, let last = intervals.last else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }

        // Use 2× padding on the leading edge so the leftmost axis label is
        // never clipped when its tick falls close to the domain boundary.
        return first.startTime.addingTimeInterval(-edgePaddingDuration * 2)...last.startTime.addingTimeInterval(edgePaddingDuration)
    }

    private var yDomain: ClosedRange<Double> {
        // Scale to the *range-filtered* maximum so the chart fills its height
        // correctly for every range, while the mark data itself (allIntervals)
        // stays constant. A small headroom factor prevents stacked area marks
        // from being clipped when independently-smoothed category sums slightly
        // exceed the smoothed total.
        let maxSmoothed = smooth(intervals.map(\.totalGenerationMW)).max() ?? 1
        return 0...(maxSmoothed * 1.05)
    }

    private var smoothedCategoryValues: [(category: String, values: [(time: Date, generationMW: Double)])] {
        categoryDomain.map { category in
            let values = allIntervals.map { interval in
                interval.categories.first { $0.category == category }?.generationMW ?? 0
            }
            let smoothedValues = smooth(values)
            let chartValues = smoothedValues
                .enumerated()
                .map { index, generationMW in
                    (time: allIntervals[index].startTime, generationMW: generationMW)
                }
            return (category, paddedChartValues(chartValues))
        }
    }

    private var smoothedTotals: [(time: Date, generationMW: Double)] {
        let chartValues = smooth(allIntervals.map(\.totalGenerationMW))
            .enumerated()
            .map { index, generationMW in
                (time: allIntervals[index].startTime, generationMW: generationMW)
            }
        return paddedChartValues(chartValues)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(partialIntervals) { interval in
                    RectangleMark(
                        xStart: .value(String(localized: "Time"), interval.startTime),
                        xEnd: .value(String(localized: "Time"), interval.endTime),
                        yStart: .value(String(localized: "Generation"), yDomain.lowerBound),
                        yEnd: .value(String(localized: "Generation"), yDomain.upperBound)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.12))
                }

                ForEach(chartPoints) { point in
                    AreaMark(
                        x: .value(String(localized: "Time"), point.time),
                        y: .value(String(localized: "Generation"), point.generationMW),
                        stacking: .standard
                    )
                    .foregroundStyle(by: .value(String(localized: "Category"), point.category))
                    .interpolationMethod(.cardinal)
                }

                ForEach(totalPoints) { point in
                    LineMark(
                        x: .value(String(localized: "Time"), point.time),
                        y: .value(String(localized: "Total"), point.generationMW)
                    )
                    .foregroundStyle(.primary.opacity(0.28))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.cardinal)
                }

                // Fall back to the last interval so the indicator is always
                // visible — on first appearance and after a range switch.
                let indicatorTime = selectedIntervalID ?? intervals.last?.startTime

                // RuleMark follows the raw drag position so it tracks the finger
                // all the way to the chart edge.
                if let rawTime = indicatorTime {
                    RuleMark(x: .value(String(localized: "Selected"), rawTime))
                        .foregroundStyle(.primary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                // PointMark shares the same raw x as the RuleMark so the dot
                // always travels with the line.  The y is linearly interpolated
                // between the two surrounding smoothed-total data points so it
                // tracks the drawn line as closely as possible.
                if let rawTime = indicatorTime,
                   let interpolatedY = interpolatedSmoothedTotal(at: rawTime) {
                    PointMark(
                        x: .value(String(localized: "Selected time"), rawTime),
                        y: .value(String(localized: "Selected total"), interpolatedY)
                    )
                    .foregroundStyle(.primary.opacity(0.72))
                    .symbolSize(58)
                }
            }
            .chartForegroundStyleScale(domain: categoryDomain, range: categoryColors)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                // Both AxisMarks blocks are always present so neither is ever
                // structurally replaced when range changes (structural replacement
                // causes Swift Charts to flash "…" during the transition).
                //
                // Visibility is controlled via opacity so SwiftUI can cross-fade:
                //   • AxisGridLine  → foregroundStyle opacity
                //   • AxisValueLabel → custom Text content with animated opacity
                //     (always in the hierarchy so the fade has something to drive)
                //
                //   24h  → 4h gridlines + hour labels visible; daily block faded out
                //   3d/7d → daily gridlines + weekday labels visible; 4h block faded out
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(range == .day ? 0.14 : 0))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let hour = Calendar.current.component(.hour, from: date)
                            Text(String(format: "%02d", hour))
                                .foregroundStyle(.secondary)
                                .opacity(range == .day ? 1 : 0)
                                .animation(.easeInOut(duration: 0.25), value: range)
                        }
                    }
                }
                AxisMarks(values: .stride(by: .day, count: 1)) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(range == .day ? 0 : 0.14))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .foregroundStyle(.secondary)
                                .opacity(range != .day ? 1 : 0)
                                .animation(.easeInOut(duration: 0.25), value: range)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(AppTheme.chartPlotBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                                    // Clamp so dragging beyond either edge still maps to a
                                    // valid domain date and the guard never silently fails.
                                    let xPosition = min(
                                        max(value.location.x - plotFrame.origin.x, 0),
                                        plotFrame.width
                                    )
                                    guard let selectedTime: Date = proxy.value(atX: xPosition) else { return }
                                    updateSelection(to: selectedTime)
                                }
                        )
                }
            }
            .chartLegend(.hidden)
            .animation(.easeInOut(duration: 0.4), value: range)
            .frame(height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Generation mix")
            .onAppear {
                if selectedIntervalID == nil {
                    selectedIntervalID = intervals.last?.startTime
                }
                syncSelectedPartial()
            }

            if let selectedInterval {
                GenerationMixSelectedIntervalView(interval: selectedInterval)
            }
        }
        .onChange(of: range) {
            // Jump to the latest interval in the new range.
            selectedIntervalID = intervals.last?.startTime
            syncSelectedPartial()
        }
    }

    /// Pushes the selected interval's preliminary state up to the parent, but
    /// only when it changes, so the parent re-renders solely on boundary crossings.
    private func syncSelectedPartial() {
        let isPartial = selectedInterval?.isPartialPublication ?? false
        if isPartial != selectedIntervalIsPartial {
            selectedIntervalIsPartial = isPartial
        }
    }

    private var selectedInterval: GenerationMixInterval? {
        guard let selectedIntervalID else { return intervals.last }
        return intervals.min {
            abs($0.startTime.timeIntervalSince(selectedIntervalID)) < abs($1.startTime.timeIntervalSince(selectedIntervalID))
        }
    }

    /// Linearly interpolates the smoothed-total y value at `time` between the
    /// two surrounding entries in `smoothedTotals`.  This keeps the PointMark
    /// dot on the drawn line regardless of where the drag position lands.
    private func interpolatedSmoothedTotal(at time: Date) -> Double? {
        let points = smoothedTotals
        guard points.isEmpty == false else { return nil }
        guard points.count >= 2 else { return points.first?.generationMW }

        guard let upperIdx = points.firstIndex(where: { $0.time >= time }) else {
            return points.last?.generationMW
        }
        guard upperIdx > 0 else { return points.first?.generationMW }

        let lower = points[upperIdx - 1]
        let upper = points[upperIdx]
        let span = upper.time.timeIntervalSince(lower.time)
        guard span > 0 else { return lower.generationMW }

        let t = time.timeIntervalSince(lower.time) / span
        return lower.generationMW + t * (upper.generationMW - lower.generationMW)
    }

    private func updateSelection(to selectedTime: Date) {
        // Store the raw drag time so the RuleMark can follow the finger exactly,
        // including into the edge-padding zone.  The selectedInterval lookup above
        // already snaps to the nearest real data interval.
        selectedIntervalID = selectedTime
        syncSelectedPartial()
    }

    private func smooth(_ values: [Double]) -> [Double] {
        guard values.count > 6 else { return values }

        return values.indices.map { index in
            let previous3 = values[max(values.startIndex, index - 3)]
            let previous2 = values[max(values.startIndex, index - 2)]
            let previous1 = values[max(values.startIndex, index - 1)]
            let current = values[index]
            let next1 = values[min(values.index(before: values.endIndex), index + 1)]
            let next2 = values[min(values.index(before: values.endIndex), index + 2)]
            let next3 = values[min(values.index(before: values.endIndex), index + 3)]
            return (previous3 * 0.06)
                + (previous2 * 0.12)
                + (previous1 * 0.18)
                + (current * 0.28)
                + (next1 * 0.18)
                + (next2 * 0.12)
                + (next3 * 0.06)
        }
    }

    private func paddedChartValues(_ values: [(time: Date, generationMW: Double)]) -> [(time: Date, generationMW: Double)] {
        guard let first = values.first, let last = values.last else { return values }

        return [
            (time: first.time.addingTimeInterval(-edgePaddingDuration), generationMW: first.generationMW),
        ] + values + [
            (time: last.time.addingTimeInterval(edgePaddingDuration), generationMW: last.generationMW),
        ]
    }
}

private struct GenerationMixCompactLegendItem: View {
    let category: GenerationMixCategory
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(generationMixColor(for: category.category))
                .frame(width: 7, height: 7)

            Text(shortGenerationMixTitle(for: category.category))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - History-only helpers

private func historyIntervalAccessibilityText(_ interval: GenerationMixInterval) -> String {
    String.localizedStringWithFormat(
        NSLocalizedString("%@, renewable mix %@", comment: "Accessibility label for one generation mix history interval"),
        timeRangeText(from: interval.startTime, to: interval.endTime),
        percentText(interval.renewableShare)
    )
}

private func shortGenerationMixTitle(for category: String) -> LocalizedStringKey {
    switch category {
    case "solar":
        return "Solar"
    case "wind":
        return "Wind"
    case "hydro":
        return "Hydro"
    case "biomass":
        return "Bio"
    case "fossil":
        return "Fossil"
    case "nuclear":
        return "Nuclear"
    default:
        return "Other"
    }
}
