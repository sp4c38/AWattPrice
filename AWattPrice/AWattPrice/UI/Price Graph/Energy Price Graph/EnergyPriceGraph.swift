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
    let startTime: Date
    let endTime: Date
    let pricePoints: [EnergyPricePoint]
    let averagePrice: Double

    var id: Date { startTime }

    init(startTime: Date, pricePoints: [EnergyPricePoint]) {
        let sortedPricePoints = pricePoints.sorted { $0.startTime < $1.startTime }

        self.startTime = startTime
        self.endTime = sortedPricePoints.last?.endTime ?? startTime
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
    let isExpandedInterval: Bool
    let showsPrice: Bool

    var timeLabel: String {
        if isExpandedInterval || showsPrice {
            return "\(formattedTime(startTime))-\(formattedTime(endTime))"
        }

        return formattedTime(startTime)
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

private struct EnergyPriceGraphLayout {
    static let axisHeight: CGFloat = 18
    static let overlayHorizontalPadding: CGFloat = 6
    static let rowSpacing: CGFloat = 0.1

    let plotHeight: CGFloat
    let rowHeight: CGFloat

    init(count: Int, availableHeight: CGFloat) {
        let localPlotHeight = max(availableHeight - Self.axisHeight, 0)
        let totalSpacing = Self.rowSpacing * CGFloat(max(count - 1, 0))

        plotHeight = localPlotHeight
        rowHeight = count == 0 ? 0 : max((localPlotHeight - totalSpacing) / CGFloat(count), 0)
    }

    func index(at locationY: CGFloat) -> Int? {
        let plotY = locationY - Self.axisHeight
        guard rowHeight > 0, plotY >= 0, plotY <= plotHeight else { return nil }

        let rowPitch = rowHeight + Self.rowSpacing
        let index = Int(plotY / rowPitch)
        guard index >= 0 else { return nil }

        let rowMinY = CGFloat(index) * rowPitch
        return plotY <= rowMinY + rowHeight ? index : nil
    }
}

private struct EnergyPriceGraphAxis: View {
    let metrics: EnergyPriceGraphMetrics
    let plotWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: plotWidth, height: EnergyPriceGraphLayout.axisHeight)

            ForEach(metrics.axisTicks, id: \.self) { tick in
                Text(tickText(for: tick))
                    .font(.caption2.weight(tick == 0 ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(tick == 0 ? .primary : .secondary)
                    .fixedSize()
                    .position(
                        x: clampedXPosition(for: tick),
                        y: 8
                    )
            }
        }
        .frame(width: plotWidth, height: EnergyPriceGraphLayout.axisHeight, alignment: .topLeading)
    }

    private func tickText(for tick: Double) -> String {
        tick == 0 ? "0" : String(format: "%.0f", tick)
    }

    private func clampedXPosition(for tick: Double) -> CGFloat {
        let rawPosition = metrics.xPosition(for: tick, width: plotWidth)
        let inset = min(PricesLayout.axisLabelSideInset, plotWidth / 2)
        return min(max(rawPosition, inset), max(plotWidth - inset, inset))
    }
}

private struct EnergyPriceValueText: View {
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .padding(.trailing, 1)

            Text("ct")
                .font(.system(size: 8, weight: .semibold, design: .rounded))

            Text("/")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .padding(.horizontal, -1)

            Text("kWh")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
        }
    }
}

private struct EnergyPriceBarRow: View {
    let row: EnergyPriceGraphDisplayRow
    let metrics: EnergyPriceGraphMetrics
    let rowHeight: CGFloat
    let plotWidth: CGFloat

    private let trackHeightFactor: CGFloat = 0.95

    private var priceText: String {
        row.price.priceString.flatMap { $0.isEmpty ? nil : $0 } ?? "0.00"
    }

    private var dayBadgeText: String {
        row.startTime.formatted(.dateTime.weekday(.abbreviated).day())
    }

    private var positiveGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.76, blue: 0.31),
                Color(red: 0.88, green: 0.38, blue: 0.25),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var negativeFill: Color {
        Color(red: 0.25, green: 0.69, blue: 0.43)
    }

    private var selectedFill: Color {
        Color(red: 0.82, green: 0.28, blue: 0.20)
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
                if row.price >= 0 {
                    positiveBar(
                        trackHeight: trackHeight,
                        barFrame: barFrame,
                        positiveGradientWidth: positiveGradientWidth,
                        zeroX: zeroX
                    )
                } else {
                    barFill(trackHeight: trackHeight, barFrame: barFrame, fill: negativeFill)
                }
            }

            if row.showsPrice, barFrame.width > 0 {
                barFill(
                    trackHeight: trackHeight,
                    barFrame: barFrame,
                    fill: selectedFill.opacity(0.82)
                )
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(row.timeLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                    if row.showsDayChange {
                        Text(dayBadgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }

                Spacer(minLength: 8)

                EnergyPriceValueText(value: priceText)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .opacity(row.showsPrice ? 1 : 0)
            }
            .padding(.horizontal, EnergyPriceGraphLayout.overlayHorizontalPadding)
            .frame(width: plotWidth, height: rowHeight)
        }
        .frame(width: plotWidth, height: rowHeight, alignment: .leading)
    }

    @ViewBuilder
    private func positiveBar(
        trackHeight: CGFloat,
        barFrame: (x: CGFloat, width: CGFloat),
        positiveGradientWidth: CGFloat,
        zeroX: CGFloat
    ) -> some View {
        let cornerRadius = min(trackHeight * 0.35, 4)
        let bar = positiveGradient
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

/// The graph drawn on the prices screen displaying the price for each upcoming hour.
struct EnergyPriceGraph: View {
    @EnvironmentObject private var energyDataService: EnergyDataService

    let displayInterval: PriceGraphDisplayInterval
    let allowsHourlyExpansion: Bool

    @State private var selectedGroupIndex: Int?
    @State private var feedbackGenerator = UISelectionFeedbackGenerator()

    private var currentPrices: [EnergyPricePoint] {
        energyDataService.energyData?.currentPrices ?? []
    }

    private var hourlyPriceGroups: [EnergyPriceHourGroup] {
        let groupedPrices = Dictionary(grouping: currentPrices) { pricePoint in
            Calendar.current.startOfHour(for: pricePoint.startTime)
        }

        return groupedPrices.keys.sorted().map { startTime in
            EnergyPriceHourGroup(
                startTime: startTime,
                pricePoints: groupedPrices[startTime] ?? []
            )
        }
    }

    private func showsDayChange(at index: Int, prices: [EnergyPricePoint]) -> Bool {
        guard index > 0 else { return false }
        return Calendar.current.isDate(prices[index - 1].startTime, inSameDayAs: prices[index].startTime) == false
    }

    private func showsDayChange(at index: Int, groups: [EnergyPriceHourGroup]) -> Bool {
        guard index > 0 else { return false }
        return Calendar.current.isDate(groups[index - 1].startTime, inSameDayAs: groups[index].startTime) == false
    }

    private func displayRows(for prices: [EnergyPricePoint], groups: [EnergyPriceHourGroup]) -> [EnergyPriceGraphDisplayRow] {
        switch displayInterval {
        case .fifteenMinutes:
            return prices.enumerated().map { index, pricePoint in
                EnergyPriceGraphDisplayRow(
                    id: "interval-\(pricePoint.startTime.timeIntervalSinceReferenceDate)",
                    groupIndex: index,
                    startTime: pricePoint.startTime,
                    endTime: pricePoint.endTime,
                    price: pricePoint.marketprice,
                    showsDayChange: showsDayChange(at: index, prices: prices),
                    isExpandedInterval: false,
                    showsPrice: selectedGroupIndex == index
                )
            }

        case .sixtyMinutes:
            return hourlyDisplayRows(for: groups)
        }
    }

    private func hourlyDisplayRows(for groups: [EnergyPriceHourGroup]) -> [EnergyPriceGraphDisplayRow] {
        groups.enumerated().flatMap { groupIndex, group in
            let groupShowsDayChange = showsDayChange(at: groupIndex, groups: groups)
            let expandsToIntervals = allowsHourlyExpansion && group.pricePoints.count > 1

            if selectedGroupIndex == groupIndex, expandsToIntervals {
                return group.pricePoints.enumerated().map { intervalIndex, pricePoint in
                    EnergyPriceGraphDisplayRow(
                        id: "interval-\(group.startTime.timeIntervalSinceReferenceDate)-\(pricePoint.startTime.timeIntervalSinceReferenceDate)",
                        groupIndex: groupIndex,
                        startTime: pricePoint.startTime,
                        endTime: pricePoint.endTime,
                        price: pricePoint.marketprice,
                        showsDayChange: groupShowsDayChange && intervalIndex == group.pricePoints.startIndex,
                        isExpandedInterval: true,
                        showsPrice: true
                    )
                }
            }

            return [
                EnergyPriceGraphDisplayRow(
                    id: "hour-\(group.startTime.timeIntervalSinceReferenceDate)",
                    groupIndex: groupIndex,
                    startTime: group.startTime,
                    endTime: group.endTime,
                    price: group.averagePrice,
                    showsDayChange: groupShowsDayChange,
                    isExpandedInterval: false,
                    showsPrice: selectedGroupIndex == groupIndex && expandsToIntervals == false
                ),
            ]
        }
    }

    private func updateSelection(to rowIndex: Int?, rows: [EnergyPriceGraphDisplayRow]) {
        let boundedGroupIndex = rowIndex.flatMap { rows.indices.contains($0) ? rows[$0].groupIndex : nil }
        guard selectedGroupIndex != boundedGroupIndex else { return }

        if boundedGroupIndex != nil {
            feedbackGenerator.selectionChanged()
            feedbackGenerator.prepare()
        }

        selectedGroupIndex = boundedGroupIndex
    }

    private var selectionAnimation: Animation {
        switch displayInterval {
        case .fifteenMinutes:
            return .easeOut(duration: 0.12)
        case .sixtyMinutes:
            guard allowsHourlyExpansion else {
                return .easeOut(duration: 0.12)
            }

            return .spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.08)
        }
    }

    private func rowTransition(for row: EnergyPriceGraphDisplayRow) -> AnyTransition {
        guard displayInterval == .sixtyMinutes, row.isExpandedInterval else {
            return .opacity
        }

        return .opacity
    }

    var body: some View {
        GeometryReader { geometry in
            let prices = currentPrices
            let groups = hourlyPriceGroups
            let rows = displayRows(for: prices, groups: groups)
            let layout = EnergyPriceGraphLayout(
                count: rows.count,
                availableHeight: geometry.size.height
            )
            let metrics = EnergyPriceGraphMetrics(prices: prices)
            let plotWidth = max(geometry.size.width, 0)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    EnergyPriceGraphAxis(metrics: metrics, plotWidth: plotWidth)

                    VStack(spacing: EnergyPriceGraphLayout.rowSpacing) {
                        ForEach(rows) { row in
                            EnergyPriceBarRow(
                                row: row,
                                metrics: metrics,
                                rowHeight: layout.rowHeight,
                                plotWidth: plotWidth
                            )
                            .transition(rowTransition(for: row))
                            .zIndex(row.isExpandedInterval ? 1 : 0)
                        }
                    }
                }
                .frame(width: plotWidth, height: geometry.size.height, alignment: .topLeading)
            }
            .animation(selectionAnimation, value: selectedGroupIndex)
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
            selectedGroupIndex = nil
        }
    }
}
