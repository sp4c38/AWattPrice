//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI
import UIKit

enum PriceGraphDisplayInterval: String, CaseIterable, Identifiable {
    case fifteenMinutes
    case sixtyMinutes

    static let defaultInterval: PriceGraphDisplayInterval = .sixtyMinutes

    var id: Self { self }

    var title: String {
        switch self {
        case .fifteenMinutes:
            return "15m"
        case .sixtyMinutes:
            return "60m"
        }
    }
}

private struct EnergyPriceGraphMetrics {
    let lowerBound: Double
    let upperBound: Double
    let minPrice: Double
    let maxPrice: Double

    init(prices: [EnergyPricePoint]) {
        let priceValues = prices.map(\.marketprice)
        let localMinPrice = priceValues.min() ?? 0
        let localMaxPrice = priceValues.max() ?? 0

        minPrice = localMinPrice
        maxPrice = localMaxPrice

        let tightLowerBound = min(localMinPrice, 0)
        let tightUpperBound = max(localMaxPrice, 0)

        if tightLowerBound == tightUpperBound {
            lowerBound = tightLowerBound
            upperBound = tightUpperBound + 1
        } else {
            lowerBound = tightLowerBound
            upperBound = tightUpperBound
        }
    }

    var axisTicks: [Double] {
        let range = upperBound - lowerBound
        let step = range > 30 ? 10.0 : 5.0
        let firstTick = ceil(lowerBound / step) * step
        var ticks: [Double] = []
        var tick = firstTick

        while tick <= upperBound {
            ticks.append(tick)
            tick += step
        }

        if ticks.contains(0) == false, lowerBound <= 0, upperBound >= 0 {
            ticks.append(0)
        }

        if ticks.isEmpty {
            ticks = [lowerBound, upperBound]
        }

        ticks.sort()
        return ticks
    }

    func xPosition(for price: Double, width: CGFloat) -> CGFloat {
        guard upperBound > lowerBound else { return 0 }

        let position = (price - lowerBound) / (upperBound - lowerBound)
        return CGFloat(position) * width
    }

    func barFrame(for price: Double, width: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let zeroX = xPosition(for: 0, width: width)
        guard price != 0 else { return (zeroX, 0) }

        let valueX = xPosition(for: price, width: width)
        return (min(zeroX, valueX), max(abs(valueX - zeroX), 2))
    }
}

private struct EnergyPriceHourGroup: Identifiable {
    let hourStartTime: Date
    let startTime: Date
    let endTime: Date
    let pricePoints: [EnergyPricePoint]
    let averagePrice: Double

    var id: Date { hourStartTime }

    init(hourStartTime: Date, pricePoints: [EnergyPricePoint]) {
        let sortedPricePoints = pricePoints.sorted { $0.startTime < $1.startTime }

        self.hourStartTime = hourStartTime
        self.startTime = sortedPricePoints.first?.startTime ?? hourStartTime
        self.endTime = sortedPricePoints.last?.endTime ?? hourStartTime
        self.pricePoints = sortedPricePoints

        if sortedPricePoints.isEmpty {
            averagePrice = 0
        } else {
            let priceSum = sortedPricePoints.reduce(0) { $0 + $1.marketprice }
            averagePrice = priceSum / Double(sortedPricePoints.count)
        }
    }
}

private struct EnergyPriceGraphDisplayRow: Identifiable {
    let id: String
    let groupIndex: Int
    let startTime: Date
    let endTime: Date
    let price: Double
    let showsDayChange: Bool
    let showsTimeLabel: Bool
    let isExpandedInterval: Bool
    let isFocused: Bool
    let showsPrice: Bool
    let showsExtremePriceText: Bool
    let showsSelectedOverlay: Bool
    let isLowestPrice: Bool
    let isHighestPrice: Bool

    var timeLabel: String {
        let calendar = Calendar.current
        let startsOnFullHour = calendar.component(.minute, from: startTime) == 0

        if isExpandedInterval || isFocused || !startsOnFullHour {
            return "\(formattedTime(startTime))-\(formattedTime(endTime))"
        }

        let hour = calendar.component(.hour, from: startTime)
        return String(format: "%02d", hour)
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

private struct EnergyPriceGraphLayout {
    static let axisHeight: CGFloat = 18
    static let overlayLeadingPadding: CGFloat = 6
    static let overlayTrailingPadding: CGFloat = 6
    static let rowSpacing: CGFloat = 0.1
    static let focusedRowWeight: CGFloat = 3.6
    static let adjacentFocusedRowWeight: CGFloat = 1.9
    static let focusedHourlyRowWeight: CGFloat = 1.7
    static let adjacentFocusedHourlyRowWeight: CGFloat = 1.25
    static let plotTopPadding: CGFloat = 10

    static let axisFontSize: CGFloat = 11
    static let axisUnitFontSize: CGFloat = 10
    static let dayBadgeFontSize: CGFloat = 11

    let plotHeight: CGFloat
    let rowHeights: [CGFloat]

    init(rowWeights: [CGFloat], availableHeight: CGFloat) {
        let localPlotHeight = max(availableHeight - Self.axisHeight - Self.plotTopPadding, 0)
        let totalSpacing = Self.rowSpacing * CGFloat(max(rowWeights.count - 1, 0))
        let availableRowsHeight = max(localPlotHeight - totalSpacing, 0)
        let totalWeight = rowWeights.reduce(0, +)

        plotHeight = localPlotHeight
        rowHeights = totalWeight > 0 ? rowWeights.map { availableRowsHeight * $0 / totalWeight } : []
    }

    func rowHeight(at index: Int) -> CGFloat {
        guard rowHeights.indices.contains(index) else { return 0 }
        return rowHeights[index]
    }

    func rowCenterY(at index: Int) -> CGFloat {
        guard rowHeights.indices.contains(index) else { return 0 }

        let precedingRowsHeight = rowHeights.prefix(index).reduce(0, +)
        let precedingSpacing = Self.rowSpacing * CGFloat(index)
        return precedingRowsHeight + precedingSpacing + (rowHeights[index] / 2)
    }

    func index(at locationY: CGFloat) -> Int? {
        let plotY = locationY - Self.axisHeight - Self.plotTopPadding
        guard plotY >= 0, plotY <= plotHeight else { return nil }

        var rowMinY: CGFloat = 0

        for index in rowHeights.indices {
            let rowHeight = rowHeights[index]
            let rowMaxY = rowMinY + rowHeight

            if plotY >= rowMinY, plotY <= rowMaxY {
                return index
            }

            rowMinY = rowMaxY + Self.rowSpacing
        }

        return nil
    }
}

private struct EnergyPriceGraphAxis: View {
    let metrics: EnergyPriceGraphMetrics
    let plotWidth: CGFloat
    private static let unitReservedWidth: CGFloat = 46

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: plotWidth, height: EnergyPriceGraphLayout.axisHeight)

            ForEach(metrics.axisTicks, id: \.self) { tick in
                Text(tickText(for: tick))
                    .font(.system(size: EnergyPriceGraphLayout.axisFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize()
                    .position(
                        x: clampedXPosition(for: tick),
                        y: 8
                    )
            }

            Text("ct/kWh")
                .font(.system(size: EnergyPriceGraphLayout.axisUnitFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize()
                .position(
                    x: max(plotWidth - (Self.unitReservedWidth / 2), Self.unitReservedWidth / 2),
                    y: 8
                )
        }
        .frame(width: plotWidth, height: EnergyPriceGraphLayout.axisHeight, alignment: .topLeading)
    }

    private func tickText(for tick: Double) -> String {
        tick == 0 ? "0" : String(format: "%.0f", tick)
    }

    private func clampedXPosition(for tick: Double) -> CGFloat {
        let rawPosition = metrics.xPosition(for: tick, width: plotWidth)
        let inset = min(PricesLayout.axisLabelSideInset, plotWidth / 2)
        let leadingInset = tick == 0 ? min(4, plotWidth / 2) : inset
        let trailingInset = min(inset + Self.unitReservedWidth, plotWidth / 2)
        return min(max(rawPosition, leadingInset), max(plotWidth - trailingInset, leadingInset))
    }
}

private struct EnergyPriceValueText: View {
    let value: String
    let isFocused: Bool

    private var valueFontSize: CGFloat {
        isFocused ? 13 : 11
    }

    var body: some View {
        Text(value)
            .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }
}

private enum EnergyPriceGraphPalette {
    static var positiveGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.76, blue: 0.24),
                Color(red: 0.86, green: 0.20, blue: 0.16),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static let selectedPositiveFill = Color(red: 0.92, green: 0.24, blue: 0.16)
    static let negativeFill = Color(red: 0.20, green: 0.70, blue: 0.38)
    static let selectedNegativeFill = Color(red: 0.02, green: 0.80, blue: 0.24)
}

private struct EnergyPriceValueBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let row: EnergyPriceGraphDisplayRow

    private var priceText: String {
        row.price.priceString.flatMap { $0.isEmpty ? nil : $0 } ?? "0.00"
    }

    private var valueBadgeShadowOpacity: Double {
        guard row.showsSelectedOverlay || row.isLowestPrice || row.isHighestPrice else { return 0 }
        return colorScheme == .dark ? 0.24 : 0.12
    }

    private var valueBadgeHighlightOpacity: Double {
        colorScheme == .dark && (row.showsSelectedOverlay || row.isLowestPrice || row.isHighestPrice) ? 0.3 : 0
    }

    var body: some View {
        HStack(spacing: 4) {
            if row.isLowestPrice {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EnergyPriceGraphPalette.negativeFill)
                    .accessibilityLabel("Lowest price")
            } else if row.isHighestPrice {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EnergyPriceGraphPalette.selectedPositiveFill)
                    .accessibilityLabel("Highest price")
            }

            EnergyPriceValueText(value: priceText, isFocused: row.isFocused)
                .foregroundStyle(.primary)
                .opacity(row.showsPrice || row.showsExtremePriceText ? 1 : 0)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.thickMaterial)
                .shadow(color: .black.opacity(valueBadgeShadowOpacity), radius: colorScheme == .dark ? 4 : 4, y: 1)
                .shadow(color: .white.opacity(valueBadgeHighlightOpacity), radius: 3)
        }
        .opacity(row.showsPrice || row.isLowestPrice || row.isHighestPrice ? 1 : 0)
    }
}

private struct EnergyPriceBarRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let row: EnergyPriceGraphDisplayRow
    let metrics: EnergyPriceGraphMetrics
    let rowHeight: CGFloat
    let plotWidth: CGFloat

    private let trackHeightFactor: CGFloat = 0.95

    private var dayBadgeText: String {
        row.startTime.formatted(.dateTime.weekday(.abbreviated).day())
    }

    private var timeLabelFontSize: CGFloat {
        row.isFocused ? 13 : 11
    }

    private var liftsValueBadge: Bool {
        (row.isLowestPrice || row.isHighestPrice) && row.isFocused == false && row.showsTimeLabel == false
    }

    private var selectedLabelShadowOpacity: Double {
        guard row.showsSelectedOverlay else { return 0 }
        return colorScheme == .dark ? 0.24 : 0.12
    }

    private var selectedLabelHighlightOpacity: Double {
        colorScheme == .dark && row.showsSelectedOverlay ? 0.3 : 0
    }

    var body: some View {
        let trackHeight = max((rowHeight - 1) * trackHeightFactor, 3)
        let barFrame = metrics.barFrame(for: row.price, width: plotWidth)
        let zeroX = metrics.xPosition(for: 0, width: plotWidth)
        let positiveGradientWidth = max(metrics.xPosition(for: metrics.upperBound, width: plotWidth) - zeroX, 1)

        ZStack(alignment: .leading) {
            Color.clear
                .frame(width: plotWidth, height: rowHeight)

            if barFrame.width > 0 {
                if row.showsSelectedOverlay {
                    barFill(
                        trackHeight: trackHeight,
                        barFrame: barFrame,
                        fill: row.price >= 0 ? EnergyPriceGraphPalette.selectedPositiveFill : EnergyPriceGraphPalette.selectedNegativeFill
                    )
                } else if row.price >= 0 {
                    positiveBar(
                        trackHeight: trackHeight,
                        barFrame: barFrame,
                        positiveGradientWidth: positiveGradientWidth,
                        zeroX: zeroX
                    )
                } else {
                    barFill(trackHeight: trackHeight, barFrame: barFrame, fill: EnergyPriceGraphPalette.negativeFill)
                }
            }

            if row.showsDayChange {
                dayChangeSeparator(around: barFrame)
            }

            HStack(spacing: 8) {
                if row.showsTimeLabel || row.showsDayChange {
                    HStack(spacing: 4) {
                        if row.showsTimeLabel {
                            Text(row.timeLabel)
                                .font(.system(size: timeLabelFontSize, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(.regularMaterial)
                                        .shadow(color: .black.opacity(selectedLabelShadowOpacity), radius: colorScheme == .dark ? 4 : 2, y: 1)
                                        .shadow(color: .white.opacity(selectedLabelHighlightOpacity), radius: 3)
                                }
                        }

                        if row.showsDayChange {
                            Text(dayBadgeText)
                                .font(.system(size: EnergyPriceGraphLayout.dayBadgeFontSize, weight: .semibold, design: .rounded))
                                .fixedSize()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                }

                Spacer(minLength: 8)

                if liftsValueBadge == false {
                    EnergyPriceValueBadge(row: row)
                }
            }
            .padding(.leading, EnergyPriceGraphLayout.overlayLeadingPadding)
            .padding(.trailing, EnergyPriceGraphLayout.overlayTrailingPadding)
            .frame(width: plotWidth, height: rowHeight)
        }
        .frame(width: plotWidth, height: rowHeight, alignment: .leading)
    }

    private func dayChangeSeparator(around barFrame: (x: CGFloat, width: CGFloat)) -> some View {
        let gap: CGFloat = 3
        let leadingWidth = max(barFrame.x - gap, 0)
        let trailingStart = min(barFrame.x + barFrame.width + gap, plotWidth)
        let trailingWidth = max(plotWidth - trailingStart, 0)

        return ZStack(alignment: .leading) {
            separatorSegment(width: leadingWidth, x: leadingWidth / 2)
            separatorSegment(width: trailingWidth, x: trailingStart + trailingWidth / 2)
        }
        .frame(width: plotWidth, height: 1.1, alignment: .leading)
        .position(x: plotWidth / 2, y: 0)
    }

    private func separatorSegment(width: CGFloat, x: CGFloat) -> some View {
        Rectangle()
            .fill(.secondary.opacity(0.45))
            .frame(width: width, height: 1.3)
            .position(x: x, y: 0.65)
    }

    @ViewBuilder
    private func positiveBar(
        trackHeight: CGFloat,
        barFrame: (x: CGFloat, width: CGFloat),
        positiveGradientWidth: CGFloat,
        zeroX: CGFloat
    ) -> some View {
        let cornerRadius = min(trackHeight * 0.35, 4)
        let bar = EnergyPriceGraphPalette.positiveGradient
            .frame(width: positiveGradientWidth, height: trackHeight)
            .offset(x: zeroX - barFrame.x)
            .frame(width: barFrame.width, height: trackHeight, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .frame(width: barFrame.width, height: trackHeight)
            .offset(x: barFrame.x)

        bar
    }

    @ViewBuilder
    private func barFill(
        trackHeight: CGFloat,
        barFrame: (x: CGFloat, width: CGFloat),
        fill: Color
    ) -> some View {
        RoundedRectangle(cornerRadius: min(trackHeight * 0.35, 4), style: .continuous)
            .fill(fill)
            .frame(width: barFrame.width, height: trackHeight)
            .offset(x: barFrame.x)
    }
}

private struct ExpandedIntervalTransitionModifier: ViewModifier, Animatable {
    let collapsedOffsetY: CGFloat
    var positionProgress: CGFloat
    var revealProgress: CGFloat
    var opacity: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                positionProgress,
                AnimatablePair(revealProgress, opacity)
            )
        }
        set {
            positionProgress = newValue.first
            revealProgress = newValue.second.first
            opacity = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        let scaleY = 0.08 + (0.92 * revealProgress)

        content
            .mask(
                Rectangle()
                    .scaleEffect(x: 1, y: scaleY, anchor: .center)
            )
            .offset(y: collapsedOffsetY * (1 - positionProgress))
            .opacity(opacity)
    }
}

/// The graph drawn on the prices screen displaying the price for each upcoming hour.
struct EnergyPriceGraph: View {
    private static let minimumHapticInterval: TimeInterval = 0.07

    @EnvironmentObject private var energyDataService: EnergyDataService

    let prices: [EnergyPricePoint]?
    let displayInterval: PriceGraphDisplayInterval
    let allowsHourlyExpansion: Bool

    init(
        prices: [EnergyPricePoint]? = nil,
        displayInterval: PriceGraphDisplayInterval,
        allowsHourlyExpansion: Bool
    ) {
        self.prices = prices
        self.displayInterval = displayInterval
        self.allowsHourlyExpansion = allowsHourlyExpansion
    }

    @State private var selectedGroupIndex: Int?
    @State private var expandedIntervalSwitchDirection: Int?
    @State private var feedbackGenerator = UISelectionFeedbackGenerator()
    @State private var lastHapticTime: TimeInterval?

    private var currentPrices: [EnergyPricePoint] {
        prices ?? energyDataService.energyData?.currentPrices ?? []
    }

    private var dataAnimationKey: String {
        currentPrices.map { pricePoint in
            let start = Int(pricePoint.startTime.timeIntervalSinceReferenceDate)
            let end = Int(pricePoint.endTime.timeIntervalSinceReferenceDate)
            let price = Int((pricePoint.marketprice * 100).rounded())
            return "\(start)-\(end)-\(price)"
        }
        .joined(separator: "|")
    }

    private var hourlyPriceGroups: [EnergyPriceHourGroup] {
        let groupedPrices = Dictionary(grouping: currentPrices) { pricePoint in
            Calendar.current.startOfHour(for: pricePoint.startTime)
        }

        return groupedPrices.keys.sorted().map { startTime in
            EnergyPriceHourGroup(
                hourStartTime: startTime,
                pricePoints: groupedPrices[startTime] ?? []
            )
        }
    }

    private func startsOnFullHour(_ date: Date) -> Bool {
        Calendar.current.component(.minute, from: date) == 0
    }

    private func showsDayChange(at index: Int, prices: [EnergyPricePoint]) -> Bool {
        guard index > 0 else { return false }
        return Calendar.current.isDate(prices[index - 1].startTime, inSameDayAs: prices[index].startTime) == false
    }

    private func showsDayChange(at index: Int, groups: [EnergyPriceHourGroup]) -> Bool {
        guard index > 0 else { return false }
        return Calendar.current.isDate(groups[index - 1].startTime, inSameDayAs: groups[index].startTime) == false
    }

    private func showsExtremes(minPrice: Double?, maxPrice: Double?) -> Bool {
        guard let minPrice, let maxPrice else { return false }
        return minPrice != maxPrice
    }

    private func isExtremePrice(_ price: Double, matching extremePrice: Double?) -> Bool {
        guard let extremePrice else { return false }
        return price == extremePrice
    }

    private func displayRows(for prices: [EnergyPricePoint], groups: [EnergyPriceHourGroup]) -> [EnergyPriceGraphDisplayRow] {
        switch displayInterval {
        case .fifteenMinutes:
            let minPrice = prices.map(\.marketprice).min()
            let maxPrice = prices.map(\.marketprice).max()
            let marksExtremes = showsExtremes(minPrice: minPrice, maxPrice: maxPrice)

            return prices.enumerated().map { index, pricePoint in
                let isSelected = selectedGroupIndex == index
                let isFullHour = startsOnFullHour(pricePoint.startTime)
                let isLowestPrice = isSelected && marksExtremes && isExtremePrice(pricePoint.marketprice, matching: minPrice)
                let isHighestPrice = isSelected && marksExtremes && isExtremePrice(pricePoint.marketprice, matching: maxPrice)

                return EnergyPriceGraphDisplayRow(
                    id: "interval-\(index)",
                    groupIndex: index,
                    startTime: pricePoint.startTime,
                    endTime: pricePoint.endTime,
                    price: pricePoint.marketprice,
                    showsDayChange: showsDayChange(at: index, prices: prices),
                    showsTimeLabel: isFullHour || isSelected,
                    isExpandedInterval: false,
                    isFocused: isSelected,
                    showsPrice: isFullHour || isSelected,
                    showsExtremePriceText: isSelected,
                    showsSelectedOverlay: isSelected,
                    isLowestPrice: isLowestPrice,
                    isHighestPrice: isHighestPrice
                )
            }

        case .sixtyMinutes:
            return hourlyDisplayRows(for: groups)
        }
    }

    private func hourlyDisplayRows(for groups: [EnergyPriceHourGroup]) -> [EnergyPriceGraphDisplayRow] {
        let minHourlyPrice = groups.map(\.averagePrice).min()
        let maxHourlyPrice = groups.map(\.averagePrice).max()
        let marksHourlyExtremes = showsExtremes(minPrice: minHourlyPrice, maxPrice: maxHourlyPrice)

        return groups.enumerated().flatMap { groupIndex, group in
            let groupShowsDayChange = showsDayChange(at: groupIndex, groups: groups)
            let expandsToIntervals = allowsHourlyExpansion && group.pricePoints.count > 1
            let isSelectedGroup = selectedGroupIndex == groupIndex

            if isSelectedGroup, expandsToIntervals {
                return group.pricePoints.enumerated().map { intervalIndex, pricePoint in
                    EnergyPriceGraphDisplayRow(
                        id: "interval-\(groupIndex)-\(intervalIndex)",
                        groupIndex: groupIndex,
                        startTime: pricePoint.startTime,
                        endTime: pricePoint.endTime,
                        price: pricePoint.marketprice,
                        showsDayChange: groupShowsDayChange && intervalIndex == group.pricePoints.startIndex,
                        showsTimeLabel: true,
                        isExpandedInterval: true,
                        isFocused: false,
                        showsPrice: true,
                        showsExtremePriceText: true,
                        showsSelectedOverlay: true,
                        isLowestPrice: false,
                        isHighestPrice: false
                    )
                }
            }

            return [
                EnergyPriceGraphDisplayRow(
                    id: "hour-\(groupIndex)",
                    groupIndex: groupIndex,
                    startTime: group.startTime,
                    endTime: group.endTime,
                    price: group.averagePrice,
                    showsDayChange: groupShowsDayChange,
                    showsTimeLabel: true,
                    isExpandedInterval: false,
                    isFocused: false,
                    showsPrice: true,
                    showsExtremePriceText: true,
                    showsSelectedOverlay: isSelectedGroup && expandsToIntervals == false,
                    isLowestPrice: isSelectedGroup == false && marksHourlyExtremes && isExtremePrice(group.averagePrice, matching: minHourlyPrice),
                    isHighestPrice: isSelectedGroup == false && marksHourlyExtremes && isExtremePrice(group.averagePrice, matching: maxHourlyPrice)
                ),
            ]
        }
    }

    private func updateSelection(to rowIndex: Int?, rows: [EnergyPriceGraphDisplayRow]) {
        let boundedGroupIndex = rowIndex.flatMap { rows.indices.contains($0) ? rows[$0].groupIndex : nil }
        guard selectedGroupIndex != boundedGroupIndex else { return }
        let currentlyShowsExpandedIntervals = selectedGroupIndex.map { selectedGroupIndex in
            rows.contains { $0.groupIndex == selectedGroupIndex && $0.isExpandedInterval }
        } ?? false
        expandedIntervalSwitchDirection = if
            currentlyShowsExpandedIntervals,
            let selectedGroupIndex,
            let boundedGroupIndex
        {
            boundedGroupIndex > selectedGroupIndex ? 1 : -1
        } else {
            nil
        }

        if boundedGroupIndex != nil {
            playSelectionFeedback()
        } else {
            lastHapticTime = nil
        }

        selectedGroupIndex = boundedGroupIndex
    }

    private func playSelectionFeedback() {
        let currentTime = ProcessInfo.processInfo.systemUptime
        if let lastHapticTime,
           currentTime - lastHapticTime < Self.minimumHapticInterval {
            return
        }

        lastHapticTime = currentTime
        feedbackGenerator.selectionChanged()
        feedbackGenerator.prepare()
    }

    private var dataChangeAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.08)
    }

    private var selectionAnimation: Animation {
        switch displayInterval {
        case .fifteenMinutes:
            return .spring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.06)
        case .sixtyMinutes:
            guard allowsHourlyExpansion else {
                return .easeOut(duration: 0.12)
            }

            return .spring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.06)
        }
    }


    private func rowTransition(
        for row: EnergyPriceGraphDisplayRow,
        collapsedOffsetY: CGFloat
    ) -> AnyTransition {
        guard displayInterval == .sixtyMinutes, row.isExpandedInterval else {
            return .opacity
        }

        if let expandedIntervalSwitchDirection {
            return .push(from: expandedIntervalSwitchDirection > 0 ? .bottom : .top)
        }

        return .asymmetric(
            insertion: .modifier(
                active: ExpandedIntervalTransitionModifier(
                    collapsedOffsetY: collapsedOffsetY,
                    positionProgress: 0,
                    revealProgress: 0.22,
                    opacity: 0.82
                ),
                identity: ExpandedIntervalTransitionModifier(
                    collapsedOffsetY: collapsedOffsetY,
                    positionProgress: 1,
                    revealProgress: 1,
                    opacity: 1
                )
            ),
            removal: .modifier(
                active: ExpandedIntervalTransitionModifier(
                    collapsedOffsetY: collapsedOffsetY,
                    positionProgress: 0,
                    revealProgress: 0.08,
                    opacity: 0
                ),
                identity: ExpandedIntervalTransitionModifier(
                    collapsedOffsetY: collapsedOffsetY,
                    positionProgress: 1,
                    revealProgress: 1,
                    opacity: 1
                )
            )
        )
    }

    private func rowZIndex(for row: EnergyPriceGraphDisplayRow) -> Double {
        if row.showsSelectedOverlay {
            return 3
        }

        if row.showsPrice || row.showsTimeLabel || row.showsDayChange {
            return 2
        }

        if row.isExpandedInterval {
            return 1
        }

        return 0
    }

    private func liftsValueBadge(for row: EnergyPriceGraphDisplayRow) -> Bool {
        (row.isLowestPrice || row.isHighestPrice) && row.isFocused == false && row.showsTimeLabel == false
    }

    private func liftedValueBadgeYOffset(for rowHeight: CGFloat) -> CGFloat {
        -max(rowHeight * 0.28, 8)
    }

    private func rowWeight(for row: EnergyPriceGraphDisplayRow, at index: Int, rows: [EnergyPriceGraphDisplayRow]) -> CGFloat {
        guard selectedGroupIndex != nil else {
            return 1
        }

        switch displayInterval {
        case .fifteenMinutes:
            guard let focusedIndex = rows.firstIndex(where: \.isFocused) else {
                return 1
            }

            if index == focusedIndex {
                return EnergyPriceGraphLayout.focusedRowWeight
            }

            if abs(index - focusedIndex) == 1 {
                return EnergyPriceGraphLayout.adjacentFocusedRowWeight
            }

            return 1

        case .sixtyMinutes:
            return 1
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let prices = currentPrices
            let groups = hourlyPriceGroups
            let rows = displayRows(for: prices, groups: groups)
            let rowWeights = rows.enumerated().map { index, row in
                rowWeight(for: row, at: index, rows: rows)
            }
            let layout = EnergyPriceGraphLayout(
                rowWeights: rowWeights,
                availableHeight: geometry.size.height
            )
            let collapsedHourlyLayout = EnergyPriceGraphLayout(
                rowWeights: Array(repeating: 1, count: groups.count),
                availableHeight: geometry.size.height
            )
            let metrics = EnergyPriceGraphMetrics(prices: prices)
            let plotWidth = max(geometry.size.width, 0)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    EnergyPriceGraphAxis(metrics: metrics, plotWidth: plotWidth)

                    VStack(spacing: EnergyPriceGraphLayout.rowSpacing) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            let collapsedOffsetY = collapsedHourlyLayout.rowCenterY(at: row.groupIndex) - layout.rowCenterY(at: index)

                            EnergyPriceBarRow(
                                row: row,
                                metrics: metrics,
                                rowHeight: layout.rowHeight(at: index),
                                plotWidth: plotWidth
                            )
                            .transition(rowTransition(
                                for: row,
                                collapsedOffsetY: collapsedOffsetY
                            ))
                            .zIndex(max(rowZIndex(for: row), row.showsSelectedOverlay ? 5 : 0))
                        }
                    }
                    .padding(.top, EnergyPriceGraphLayout.plotTopPadding)
                    .clipped()
                }
                .frame(width: plotWidth, height: geometry.size.height, alignment: .topLeading)

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if liftsValueBadge(for: row) {
                        HStack {
                            Spacer(minLength: 0)

                            EnergyPriceValueBadge(row: row)
                        }
                        .padding(.leading, EnergyPriceGraphLayout.overlayLeadingPadding)
                        .padding(.trailing, EnergyPriceGraphLayout.overlayTrailingPadding)
                        .frame(width: plotWidth, height: layout.rowHeight(at: index), alignment: .trailing)
                        .position(
                            x: plotWidth / 2,
                            y: EnergyPriceGraphLayout.axisHeight
                                + EnergyPriceGraphLayout.plotTopPadding
                                + layout.rowCenterY(at: index)
                                + liftedValueBadgeYOffset(for: layout.rowHeight(at: index))
                        )
                        .zIndex(4)
                        .allowsHitTesting(false)
                    }
                }
            }
            .animation(selectionAnimation, value: selectedGroupIndex)
            .animation(dataChangeAnimation, value: dataAnimationKey)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(to: layout.index(at: value.location.y), rows: rows)
                    }
                    .onEnded { _ in
                        updateSelection(to: nil, rows: rows)
                    }
            )
        }
        .onAppear {
            feedbackGenerator.prepare()
        }
        .onChange(of: displayInterval) { _, _ in
            expandedIntervalSwitchDirection = nil
            selectedGroupIndex = nil
        }
        .onChange(of: dataAnimationKey) { _, _ in
            expandedIntervalSwitchDirection = nil
            selectedGroupIndex = nil
        }
        .dynamicTypeSize(.medium)
    }
}
