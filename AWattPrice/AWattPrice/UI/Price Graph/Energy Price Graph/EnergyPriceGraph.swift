//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

struct GraphHeader: View {
    var body: some View {
        HStack {
            Text("Time of day")

            Spacer()

            Text("Cent per kWh")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
    }
}

private struct EnergyPriceGraphMetrics {
    let maxPrice: Double

    init(prices: [EnergyPricePoint]) {
        let priceValues = prices.map(\.marketprice)
        maxPrice = max(priceValues.map(abs).max() ?? 0, 1)
    }

    func barWidth(for price: Double, availableWidth: CGFloat) -> CGFloat {
        guard price != 0 else { return 0 }
        let scaledWidth = max(CGFloat(abs(price) / maxPrice) * availableWidth, 2)
        return min(scaledWidth, availableWidth)
    }
}

private struct EnergyPriceGraphLayout {
    static let rowSpacing: CGFloat = 0.25

    let rowHeight: CGFloat

    init(count: Int, availableHeight: CGFloat) {
        let totalSpacing = Self.rowSpacing * CGFloat(max(count - 1, 0))
        let localRowHeight = count == 0 ? 0 : max((availableHeight - totalSpacing) / CGFloat(count), 0)

        rowHeight = localRowHeight
    }
}

private struct EnergyPriceBarRow: View {
    let pricePoint: EnergyPricePoint
    let metrics: EnergyPriceGraphMetrics
    let rowHeight: CGFloat
    let showsDayChange: Bool

    private let horizontalLabelPadding: CGFloat = 5
    private let verticalLabelPadding: CGFloat = 2
    private let labelCornerRadius: CGFloat = 5
    private let trackHeightFactor: CGFloat = 0.9

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
                Color(red: 0.93, green: 0.32, blue: 0.29),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var negativeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.35, green: 0.77, blue: 0.55),
                Color(red: 0.14, green: 0.46, blue: 0.39),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let trackHeight = max((rowHeight - 1) * trackHeightFactor, 10)
            let barWidth = metrics.barWidth(for: pricePoint.marketprice, availableWidth: geometry.size.width)
            let gradient = pricePoint.marketprice >= 0 ? positiveGradient : negativeGradient

            ZStack(alignment: .leading) {
                if barWidth > 0 {
                    gradient
                        .mask(
                            RoundedRectangle(cornerRadius: min(trackHeight * 0.18, 4), style: .continuous)
                                .frame(width: barWidth, height: trackHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    Text(timeRangeText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .padding(.horizontal, horizontalLabelPadding)
                        .padding(.vertical, verticalLabelPadding)
                        .background(
                            RoundedRectangle(cornerRadius: labelCornerRadius, style: .continuous)
                                .fill(Color.white.opacity(0.8))
                        )
                        .frame(height: 20, alignment: .center)

                    if showsDayChange {
                        Text(dayBadgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.72), in: Capsule())
                    }

                    Spacer(minLength: 8)

                    Text(priceText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .padding(.horizontal, horizontalLabelPadding + 1)
                        .padding(.vertical, verticalLabelPadding)
                        .background(
                            RoundedRectangle(cornerRadius: labelCornerRadius, style: .continuous)
                                .fill(Color.white.opacity(0.78))
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 20, alignment: .center)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
    }
}

/// The graph drawn on the prices screen displaying the price for each upcoming hour.
struct EnergyPriceGraph: View {
    @EnvironmentObject private var energyDataService: EnergyDataService

    private var currentPrices: [EnergyPricePoint] {
        energyDataService.energyData?.currentPrices ?? []
    }

    private func showsDayChange(at index: Int, prices: [EnergyPricePoint]) -> Bool {
        guard index > 0 else { return false }
        return Calendar.current.isDate(prices[index - 1].startTime, inSameDayAs: prices[index].startTime) == false
    }

    var body: some View {
        GeometryReader { geometry in
            let prices = currentPrices
            let layout = EnergyPriceGraphLayout(
                count: prices.count,
                availableHeight: geometry.size.height
            )
            let metrics = EnergyPriceGraphMetrics(prices: prices)

            VStack(spacing: EnergyPriceGraphLayout.rowSpacing) {
                ForEach(Array(prices.enumerated()), id: \.offset) { index, pricePoint in
                    EnergyPriceBarRow(
                        pricePoint: pricePoint,
                        metrics: metrics,
                        rowHeight: layout.rowHeight,
                        showsDayChange: showsDayChange(at: index, prices: prices)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
