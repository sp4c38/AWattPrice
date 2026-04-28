//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI
import UIKit

struct GraphHeader: View {
    var body: some View {
        HStack {
            Text("Time")

            Spacer()

            Text("ct/kWh")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
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

private struct EnergyPriceGraphLayout {
    static let axisHeight: CGFloat = 24
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
                        x: metrics.xPosition(for: tick, width: plotWidth),
                        y: 8
                    )
            }
        }
        .frame(width: plotWidth, height: EnergyPriceGraphLayout.axisHeight, alignment: .topLeading)
    }

    private func tickText(for tick: Double) -> String {
        tick == 0 ? "0" : String(format: "%.0f", tick)
    }
}

private struct EnergyPriceBarRow: View {
    let pricePoint: EnergyPricePoint
    let metrics: EnergyPriceGraphMetrics
    let rowHeight: CGFloat
    let plotWidth: CGFloat
    let hourLabel: String?
    let isSelected: Bool
    let showsDayChange: Bool

    private let trackHeightFactor: CGFloat = 0.95

    private var hourText: String {
        pricePoint.startTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private var timeRangeText: String {
        let startHour = pricePoint.startTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let endHour = pricePoint.endTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "\(startHour)-\(endHour)"
    }

    private var priceText: String {
        let formattedPrice = pricePoint.marketprice.priceString.flatMap { $0.isEmpty ? nil : $0 } ?? "0.00"
        return "\(formattedPrice) ct"
    }

    private var dayBadgeText: String {
        pricePoint.startTime.formatted(.dateTime.weekday(.abbreviated).day())
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

    var body: some View {
        let trackHeight = max((rowHeight - 1) * trackHeightFactor, 3)
        let barFrame = metrics.barFrame(for: pricePoint.marketprice, width: plotWidth)
        let zeroX = metrics.xPosition(for: 0, width: plotWidth)
        let positiveGradientWidth = max(metrics.xPosition(for: metrics.upperBound, width: plotWidth) - zeroX, 1)

        ZStack(alignment: .leading) {
            Color.clear
                .frame(width: plotWidth, height: rowHeight)

            if barFrame.width > 0 {
                if pricePoint.marketprice >= 0 {
                    ZStack(alignment: .leading) {
                        Color.clear
                            .frame(width: plotWidth, height: rowHeight)

                        positiveGradient
                            .frame(width: positiveGradientWidth, height: trackHeight)
                            .offset(x: zeroX)
                    }
                    .mask {
                        ZStack(alignment: .leading) {
                            Color.clear
                                .frame(width: plotWidth, height: rowHeight)

                            RoundedRectangle(cornerRadius: min(trackHeight * 0.35, 4), style: .continuous)
                                .frame(width: barFrame.width, height: trackHeight)
                                .offset(x: barFrame.x)
                        }
                    }
                    .frame(width: plotWidth, height: rowHeight, alignment: .leading)
                } else {
                    RoundedRectangle(cornerRadius: min(trackHeight * 0.35, 4), style: .continuous)
                        .fill(negativeFill)
                        .frame(width: barFrame.width, height: trackHeight)
                        .offset(x: barFrame.x)
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    if isSelected || hourLabel != nil {
                        Text(isSelected ? timeRangeText : (hourLabel ?? ""))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }

                    if showsDayChange {
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

                Text(priceText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, EnergyPriceGraphLayout.overlayHorizontalPadding)
            .frame(width: plotWidth, height: rowHeight)
        }
        .frame(width: plotWidth, height: rowHeight, alignment: .leading)
    }
}

/// The graph drawn on the prices screen displaying the price for each upcoming hour.
struct EnergyPriceGraph: View {
    @EnvironmentObject private var energyDataService: EnergyDataService

    @State private var selectedIndex: Int?
    @State private var feedbackGenerator = UISelectionFeedbackGenerator()

    private var currentPrices: [EnergyPricePoint] {
        energyDataService.energyData?.currentPrices ?? []
    }

    private func hourLabel(for pricePoint: EnergyPricePoint) -> String? {
        let minute = Calendar.current.component(.minute, from: pricePoint.startTime)
        guard minute == 0 else { return nil }

        return pricePoint.startTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private func showsDayChange(at index: Int, prices: [EnergyPricePoint]) -> Bool {
        guard index > 0 else { return false }
        return Calendar.current.isDate(prices[index - 1].startTime, inSameDayAs: prices[index].startTime) == false
    }

    private func updateSelection(to newIndex: Int?, prices: [EnergyPricePoint]) {
        let boundedIndex = newIndex.flatMap { prices.indices.contains($0) ? $0 : nil }
        guard selectedIndex != boundedIndex else { return }

        if boundedIndex != nil {
            feedbackGenerator.selectionChanged()
            feedbackGenerator.prepare()
        }

        selectedIndex = boundedIndex
    }

    var body: some View {
        GeometryReader { geometry in
            let prices = currentPrices
            let layout = EnergyPriceGraphLayout(
                count: prices.count,
                availableHeight: geometry.size.height
            )
            let metrics = EnergyPriceGraphMetrics(prices: prices)
            let plotWidth = max(geometry.size.width, 0)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    EnergyPriceGraphAxis(metrics: metrics, plotWidth: plotWidth)

                    VStack(spacing: EnergyPriceGraphLayout.rowSpacing) {
                        ForEach(Array(prices.enumerated()), id: \.offset) { index, pricePoint in
                            EnergyPriceBarRow(
                                pricePoint: pricePoint,
                                metrics: metrics,
                                rowHeight: layout.rowHeight,
                                plotWidth: plotWidth,
                                hourLabel: hourLabel(for: pricePoint),
                                isSelected: selectedIndex == index,
                                showsDayChange: showsDayChange(at: index, prices: prices)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .animation(.easeOut(duration: 0.12), value: selectedIndex)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(to: layout.index(at: value.location.y), prices: prices)
                    }
                    .onEnded { _ in
                        updateSelection(to: nil, prices: prices)
                    }
            )
        }
        .onAppear {
            feedbackGenerator.prepare()
        }
    }
}
