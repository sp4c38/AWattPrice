//
//  InsightsView.swift
//  AWattPrice
//
//  Created by Codex on 28.04.26.
//

import SwiftUI

private let insightsAccent = AppTheme.accent

private struct PriceWindow: Identifiable {
    let id = UUID()
    let title: String
    let startTime: Date
    let endTime: Date
    let averagePrice: Double
}

private struct InsightsModel {
    let prices: [EnergyPricePoint]

    private var now: Date { Date() }

    var currentPrice: EnergyPricePoint? {
        prices.first { $0.startTime <= now && $0.endTime > now } ?? prices.first
    }

    var averagePrice: Double? {
        weightedAverage(for: prices)
    }

    var minPrice: EnergyPricePoint? {
        prices.min(by: EnergyPricePoint.marketpricesAreInIncreasingOrder)
    }

    var maxPrice: EnergyPricePoint? {
        prices.max(by: EnergyPricePoint.marketpricesAreInIncreasingOrder)
    }

    var priceRange: ClosedRange<Double>? {
        guard let minPrice, let maxPrice else { return nil }
        return minPrice.marketprice...maxPrice.marketprice
    }

    var averageTimeRange: (startTime: Date, endTime: Date)? {
        guard let firstPrice = prices.first, let lastPrice = prices.last else { return nil }
        return (firstPrice.startTime, lastPrice.endTime)
    }

    var cheapestWindows: [PriceWindow] {
        [
            cheapestWindow(duration: 60 * 60, title: "1h usage"),
            cheapestWindow(duration: 2 * 60 * 60, title: "2h usage"),
            cheapestWindow(duration: 4 * 60 * 60, title: "4h usage"),
        ]
        .compactMap { $0 }
    }

    func rangePosition(for price: Double) -> CGFloat {
        guard
            let priceRange,
            priceRange.upperBound > priceRange.lowerBound
        else {
            return 0.5
        }

        return CGFloat((price - priceRange.lowerBound) / (priceRange.upperBound - priceRange.lowerBound))
    }

    private func cheapestWindow(duration: TimeInterval, title: String) -> PriceWindow? {
        guard prices.isEmpty == false else { return nil }

        var bestWindow: PriceWindow?

        for startIndex in prices.indices {
            var selectedPrices: [EnergyPricePoint] = []
            var endIndex = startIndex

            while endIndex < prices.endIndex,
                  prices[endIndex].endTime.timeIntervalSince(prices[startIndex].startTime) <= duration {
                selectedPrices.append(prices[endIndex])
                endIndex += 1
            }

            guard
                let firstPrice = selectedPrices.first,
                let lastPrice = selectedPrices.last,
                lastPrice.endTime.timeIntervalSince(firstPrice.startTime) >= duration,
                let averagePrice = weightedAverage(for: selectedPrices)
            else {
                continue
            }

            let window = PriceWindow(
                title: title,
                startTime: firstPrice.startTime,
                endTime: lastPrice.endTime,
                averagePrice: averagePrice
            )

            if bestWindow == nil || window.averagePrice < bestWindow!.averagePrice {
                bestWindow = window
            }
        }

        return bestWindow
    }

    private func weightedAverage(for prices: [EnergyPricePoint]) -> Double? {
        guard prices.isEmpty == false else { return nil }

        let totalDuration = prices.reduce(0) { partialResult, pricePoint in
            partialResult + pricePoint.endTime.timeIntervalSince(pricePoint.startTime)
        }

        guard totalDuration > 0 else { return nil }

        let weightedSum = prices.reduce(0) { partialResult, pricePoint in
            let duration = pricePoint.endTime.timeIntervalSince(pricePoint.startTime)
            return partialResult + pricePoint.marketprice * duration
        }

        return weightedSum / totalDuration
    }
}

private struct InsightsCard<Content: View>: View {
    let tint: Color?
    @ViewBuilder let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(cornerRadius: 16, padding: 0)
    }
}

private struct InsightsSectionTitle: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .font(.headline)
    }
}

private struct PriceWindowRow: View {
    let window: PriceWindow
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(tint.opacity(0.75))
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.title)
                    .font(.subheadline.weight(.semibold))

                Text(timeRangeText(from: window.startTime, to: window.endTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(priceText(window.averagePrice))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct PriceRangeGraph: View {
    let model: InsightsModel

    private let railY: CGFloat = 52
    private let currentLabelY: CGFloat = 27
    private let currentLabelWidth: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.12))
                        .frame(height: 8)
                        .position(x: geometry.size.width / 2, y: railY)

                    if let minPrice = model.minPrice {
                        PriceRangeMarker(
                            label: "Lowest",
                            price: minPrice.marketprice,
                            tint: AppTheme.success
                        )
                        .position(x: markerX(for: minPrice.marketprice, width: geometry.size.width), y: railY)
                    }

                    if let averagePrice = model.averagePrice {
                        PriceRangeMarker(
                            label: "Average",
                            price: averagePrice,
                            tint: Color.secondary
                        )
                        .position(x: markerX(for: averagePrice, width: geometry.size.width), y: railY)
                    }

                    if let maxPrice = model.maxPrice {
                        PriceRangeMarker(
                            label: "Highest",
                            price: maxPrice.marketprice,
                            tint: AppTheme.error
                        )
                        .position(x: markerX(for: maxPrice.marketprice, width: geometry.size.width), y: railY)
                    }

                    if let currentPrice = model.currentPrice {
                        CurrentPriceRangeMarker(
                            price: currentPrice.marketprice,
                            tint: insightsAccent,
                            connectorHeight: 14
                        )
                        .position(
                            x: currentLabelX(for: currentPrice.marketprice, width: geometry.size.width),
                            y: currentLabelY
                        )
                    }
                }
            }
            .frame(height: 68)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rangeAccessibilityLabel)

            HStack(alignment: .top, spacing: 8) {
                RangeValueLabel(
                    title: "Lowest",
                    value: model.minPrice?.marketprice,
                    subtitle: model.minPrice.map { timeRangeText(from: $0.startTime, to: $0.endTime) },
                    alignment: .leading,
                    tint: AppTheme.success
                )
                Spacer()
                RangeValueLabel(
                    title: "Average",
                    value: model.averagePrice,
                    subtitle: nil,
                    alignment: .center,
                    tint: Color.secondary
                )
                Spacer()
                RangeValueLabel(
                    title: "Highest",
                    value: model.maxPrice?.marketprice,
                    subtitle: model.maxPrice.map { timeRangeText(from: $0.startTime, to: $0.endTime) },
                    alignment: .trailing,
                    tint: AppTheme.error
                )
            }
        }
    }

    private var rangeAccessibilityLabel: String {
        String.localizedStringWithFormat(
            NSLocalizedString("Price range from %@ to %@, average %@", comment: "Accessibility label for the insights price range"),
            priceText(model.minPrice?.marketprice),
            priceText(model.maxPrice?.marketprice),
            priceText(model.averagePrice)
        )
    }

    private func markerX(for price: Double, width: CGFloat) -> CGFloat {
        min(max(model.rangePosition(for: price) * width, 8), max(width - 8, 8))
    }

    private func currentLabelX(for price: Double, width: CGFloat) -> CGFloat {
        let halfWidth = currentLabelWidth / 2
        return min(
            max(model.rangePosition(for: price) * width, halfWidth),
            max(width - halfWidth, halfWidth)
        )
    }
}

private struct PriceRangeMarker: View {
    let label: LocalizedStringKey
    let price: Double
    let tint: Color

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                    .stroke(.background, lineWidth: 3)
            }
            .shadow(color: tint.opacity(0.24), radius: 4, y: 2)
            .accessibilityLabel(label)
            .accessibilityValue(priceText(price))
    }
}

private struct CurrentPriceRangeMarker: View {
    let price: Double
    let tint: Color
    let connectorHeight: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            VStack(alignment: .center, spacing: 3) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)

                    Text("Current")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(priceText(price))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Rectangle()
                .fill(tint.opacity(0.45))
                .frame(width: 2, height: connectorHeight)

            Circle()
                .fill(tint)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .stroke(.background, lineWidth: 3)
                }
                .shadow(color: tint.opacity(0.24), radius: 4, y: 2)
        }
        .frame(width: 112)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current")
        .accessibilityValue(priceText(price))
    }
}

private struct RangeValueLabel: View {
    let title: LocalizedStringKey
    let value: Double?
    let subtitle: String?
    let alignment: HorizontalAlignment
    let tint: Color

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(priceText(value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(textAlignment)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(textAlignment)
            }
        }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }
}

struct InsightsView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @AppStorage("pendingDeepLinkDestination") private var pendingDeepLinkDestination = ""
    @State private var navigateToCheapestTime = false

    private var prices: [EnergyPricePoint] {
        energyDataService.energyData?.currentPrices ?? []
    }

    private var model: InsightsModel {
        InsightsModel(prices: prices)
    }

    var body: some View {
        NavigationStack {
            Group {
                if prices.isEmpty {
                    DataDownloadAndError()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            InsightsCard(tint: AppTheme.accent) {
                                InsightsSectionTitle(
                                    title: "Price range",
                                    systemImage: "chart.bar.fill",
                                    tint: AppTheme.accent
                                )

                                PriceRangeGraph(model: model)
                            }

                            InsightsCard(tint: AppTheme.success) {
                                HStack {
                                    InsightsSectionTitle(
                                        title: "Cheapest times",
                                        systemImage: "timer",
                                        tint: AppTheme.success
                                    )

                                    Spacer()

                                    NavigationLink {
                                        CheapestTimeView()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text("Custom")
                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.bold))
                                        }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.accent)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Open Cheapest Time")
                                }

                                ForEach(model.cheapestWindows) { window in
                                    PriceWindowRow(window: window, tint: AppTheme.success)
                                }
                            }

                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .appScreenBackground()
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $navigateToCheapestTime) {
                CheapestTimeView()
            }
            .onAppear(perform: handlePendingDeepLink)
            .onChange(of: pendingDeepLinkDestination) {
                handlePendingDeepLink()
            }
        }
    }

    private func handlePendingDeepLink() {
        guard pendingDeepLinkDestination == AppDeepLinkDestination.cheapestTime.rawValue else { return }

        pendingDeepLinkDestination = ""
        navigateToCheapestTime = true
    }
}

private func priceText(_ price: Double?) -> String {
    guard let price else { return "-" }
    let formattedPrice = price.priceString.flatMap { $0.isEmpty ? "0.00" : $0 } ?? "0.00"
    return "\(formattedPrice) ct"
}

private func timeRangeText(from startTime: Date, to endTime: Date) -> String {
    let start = startTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    let end = endTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    return "\(start)-\(end)"
}
