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
            Text("Time of day")

            Spacer()

            Text("Cent per kWh")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
    }
}

private enum EnergyPriceGraphEmphasis: Equatable {
    case standard
    case adjacent
    case selected

    var trackHeightFactor: CGFloat {
        switch self {
        case .standard:
            return 0.9
        case .adjacent:
            return 0.92
        case .selected:
            return 1.90
        }
    }

    var labelScale: CGFloat {
        switch self {
        case .standard:
            return 1
        case .adjacent:
            return 1
        case .selected:
            return 1.22
        }
    }

    var horizontalLabelPadding: CGFloat {
        switch self {
        case .standard:
            return 5
        case .adjacent:
            return 5
        case .selected:
            return 6
        }
    }

    var verticalLabelPadding: CGFloat {
        switch self {
        case .standard:
            return 2
        case .adjacent:
            return 2
        case .selected:
            return 3
        }
    }

    var labelCornerRadius: CGFloat {
        switch self {
        case .standard:
            return 5
        case .adjacent:
            return 5
        case .selected:
            return 6
        }
    }

    var highlightOpacity: Double {
        switch self {
        case .standard, .adjacent:
            return 0
        case .selected:
            return 0.06
        }
    }
}

private struct EnergyPriceGraphMetrics {
    let maxPrice: Double

    init(prices: [EnergyPricePoint]) {
        let priceValues = prices.map(\.marketprice)
        maxPrice = max(priceValues.map(abs).max() ?? 0, 1)
    }

    func barFrame(for price: Double, width: CGFloat) -> (x: CGFloat, width: CGFloat) {
        guard price != 0 else { return (0, 0) }
        let scaledWidth = max(CGFloat(abs(price) / maxPrice) * width, 2)
        return (0, min(scaledWidth, width))
    }
}

private struct EnergyPriceGraphLayout {
    let rowHeight: CGFloat
    let rowCenters: [CGFloat]
    let rowSpacing: CGFloat
    let availableHeight: CGFloat

    init(count: Int, availableHeight: CGFloat) {
        let localRowSpacing: CGFloat = 0.25

        let totalSpacing = localRowSpacing * CGFloat(max(count - 1, 0))
        let localRowHeight = count == 0 ? 0 : max((availableHeight - totalSpacing) / CGFloat(count), 0)
        let centers = (0 ..< count).map { index in
            CGFloat(index) * (localRowHeight + localRowSpacing) + localRowHeight / 2
        }

        rowSpacing = localRowSpacing
        rowHeight = localRowHeight
        rowCenters = centers
        self.availableHeight = availableHeight
    }

    func index(at locationY: CGFloat) -> Int? {
        guard rowHeight > 0, rowCenters.isEmpty == false else { return nil }

        for (index, centerY) in rowCenters.enumerated() {
            let minY = centerY - rowHeight / 2
            let maxY = centerY + rowHeight / 2
            if locationY >= minY, locationY <= maxY {
                return index
            }
        }
        return nil
    }
}

private enum EnergyPriceGraphExpansionAnchor {
    case centered
    case lockTop
    case lockBottom
}

private struct EnergyPriceBarRow: View {
    let pricePoint: EnergyPricePoint
    let emphasis: EnergyPriceGraphEmphasis
    let metrics: EnergyPriceGraphMetrics
    let rowHeight: CGFloat
    let showsDayChange: Bool
    let expansionAnchor: EnergyPriceGraphExpansionAnchor

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

    private var rowBackgroundFillColor: Color {
        Color(red: 0.95, green: 0.50, blue: 0.23, opacity: emphasis.highlightOpacity)
    }

    var body: some View {
        GeometryReader { geometry in
            let baseTrackHeight = max((rowHeight - 1) * EnergyPriceGraphEmphasis.standard.trackHeightFactor, 10)
            let trackHeight = max((rowHeight - 1) * emphasis.trackHeightFactor, 10)
            let barFrame = metrics.barFrame(for: pricePoint.marketprice, width: geometry.size.width)
            let gradient = pricePoint.marketprice >= 0 ? positiveGradient : negativeGradient
            let inwardOffset = switch expansionAnchor {
            case .centered:
                CGFloat.zero
            case .lockTop:
                (trackHeight - baseTrackHeight) / 2
            case .lockBottom:
                -(trackHeight - baseTrackHeight) / 2
            }

            ZStack(alignment: .leading) {
                if barFrame.width > 0 {
                    gradient
                        .mask(
                            RoundedRectangle(cornerRadius: min(trackHeight * 0.18, 4), style: .continuous)
                                .frame(width: barFrame.width, height: trackHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    Text(timeRangeText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .padding(.horizontal, emphasis.horizontalLabelPadding)
                        .padding(.vertical, emphasis.verticalLabelPadding)
                        .background(
                            RoundedRectangle(cornerRadius: emphasis.labelCornerRadius, style: .continuous)
                                .fill(Color.white.opacity(emphasis == .selected ? 0.9 : 0.8))
                        )
                        .scaleEffect(emphasis.labelScale)
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
                        .padding(.horizontal, emphasis.horizontalLabelPadding + 1)
                        .padding(.vertical, emphasis.verticalLabelPadding)
                        .background(
                            RoundedRectangle(cornerRadius: emphasis.labelCornerRadius, style: .continuous)
                                .fill(Color.white.opacity(emphasis == .selected ? 0.9 : 0.78))
                        )
                        .scaleEffect(emphasis.labelScale)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 20, alignment: .center)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .offset(y: inwardOffset)
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowBackgroundFillColor)
        )
    }
}

/// The interactive graph drawn on the prices screen displaying the price for each upcoming hour.
struct EnergyPriceGraph: View {
    @EnvironmentObject private var energyDataService: EnergyDataService

    @State private var selectedIndex: Int?
    @State private var feedbackGenerator = UISelectionFeedbackGenerator()

    private var currentPrices: [EnergyPricePoint] {
        energyDataService.energyData?.currentPrices ?? []
    }

    private func emphasis(for index: Int) -> EnergyPriceGraphEmphasis {
        guard let selectedIndex else { return .standard }

        switch abs(index - selectedIndex) {
        case 0:
            return .selected
        case 1:
            return .adjacent
        default:
            return .standard
        }
    }

    private var selectionAnimation: Animation {
        .interactiveSpring(response: 0.34, dampingFraction: 0.38, blendDuration: 0.15)
    }

    private func rowDisplacement(for index: Int, layout: EnergyPriceGraphLayout) -> CGFloat {
        guard let selectedIndex else { return 0 }
        guard index != selectedIndex else { return 0 }

        let direction: CGFloat = index < selectedIndex ? -1 : 1
        let pushDistance = min(max(layout.rowHeight * 0.18, 1.5), 4.5)
        return direction * pushDistance
    }

    private func visualHalfHeight(for emphasis: EnergyPriceGraphEmphasis, rowHeight: CGFloat) -> CGFloat {
        max((rowHeight - 1) * emphasis.trackHeightFactor, 8) / 2
    }

    private func rowPositionY(for index: Int, layout: EnergyPriceGraphLayout) -> CGFloat {
        let baseY = layout.rowCenters[index]
        let displacedY = baseY + rowDisplacement(for: index, layout: layout)

        guard selectedIndex != nil else { return displacedY }

        let topEdge = currentPrices.indices.reduce(CGFloat.greatestFiniteMagnitude) { partialResult, currentIndex in
            let emphasis = emphasis(for: currentIndex)
            let centerY = layout.rowCenters[currentIndex] + rowDisplacement(for: currentIndex, layout: layout)
            return min(partialResult, centerY - visualHalfHeight(for: emphasis, rowHeight: layout.rowHeight))
        }

        let bottomEdge = currentPrices.indices.reduce(-CGFloat.greatestFiniteMagnitude) { partialResult, currentIndex in
            let emphasis = emphasis(for: currentIndex)
            let centerY = layout.rowCenters[currentIndex] + rowDisplacement(for: currentIndex, layout: layout)
            return max(partialResult, centerY + visualHalfHeight(for: emphasis, rowHeight: layout.rowHeight))
        }

        let compensation: CGFloat
        if topEdge < 0 {
            compensation = -topEdge
        } else if bottomEdge > layout.availableHeight {
            compensation = layout.availableHeight - bottomEdge
        } else {
            compensation = 0
        }

        return displacedY + compensation
    }

    private func showsDayChange(at index: Int, prices: [EnergyPricePoint]) -> Bool {
        guard index > 0 else { return false }
        return Calendar.current.isDate(prices[index - 1].startTime, inSameDayAs: prices[index].startTime) == false
    }

    private func expansionAnchor(for index: Int, prices: [EnergyPricePoint]) -> EnergyPriceGraphExpansionAnchor {
        guard selectedIndex == index else { return .centered }
        if index == 0 { return .lockTop }
        if index == prices.count - 1 { return .lockBottom }
        return .centered
    }

    private func updateSelection(to newIndex: Int?) {
        guard selectedIndex != newIndex else { return }

        if newIndex != nil {
            feedbackGenerator.selectionChanged()
            feedbackGenerator.prepare()
        }

        selectedIndex = newIndex
    }

    var body: some View {
        GeometryReader { geometry in
            let prices = currentPrices
            let layout = EnergyPriceGraphLayout(
                count: prices.count,
                availableHeight: geometry.size.height
            )
            let metrics = EnergyPriceGraphMetrics(prices: prices)

            ZStack {
                ForEach(Array(prices.enumerated()), id: \.offset) { index, pricePoint in
                    EnergyPriceBarRow(
                        pricePoint: pricePoint,
                        emphasis: emphasis(for: index),
                        metrics: metrics,
                        rowHeight: layout.rowHeight,
                        showsDayChange: showsDayChange(at: index, prices: prices),
                        expansionAnchor: expansionAnchor(for: index, prices: prices)
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: rowPositionY(for: index, layout: layout)
                    )
                    .zIndex(selectedIndex == index ? 1 : 0)
                }
            }
            .animation(selectionAnimation, value: selectedIndex)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nextIndex = layout.index(at: value.location.y)
                        updateSelection(to: nextIndex)
                    }
                    .onEnded { _ in
                        updateSelection(to: nil)
                    }
            )
        }
        .onAppear {
            feedbackGenerator.prepare()
        }
    }
}
