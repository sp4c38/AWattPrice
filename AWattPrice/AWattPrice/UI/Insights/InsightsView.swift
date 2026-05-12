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

private struct PriceBand: Identifiable {
    let id = UUID()
    let title: String
    let rangeText: String
    let count: Int
    let tint: Color
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

    var cheapestWindows: [PriceWindow] {
        [
            cheapestWindow(duration: 60 * 60, title: "Cheapest 1h"),
            cheapestWindow(duration: 2 * 60 * 60, title: "Cheapest 2h"),
            cheapestWindow(duration: 4 * 60 * 60, title: "Cheapest 4h"),
        ]
        .compactMap { $0 }
    }

    var priceBands: [PriceBand] {
        [
            PriceBand(
                title: "Negative",
                rangeText: "< 0 ct",
                count: prices.filter { $0.marketprice < 0 }.count,
                tint: Color(red: 0.25, green: 0.69, blue: 0.43)
            ),
            PriceBand(
                title: "Low",
                rangeText: "0-5 ct",
                count: prices.filter { $0.marketprice >= 0 && $0.marketprice < 5 }.count,
                tint: Color(red: 1.00, green: 0.76, blue: 0.31)
            ),
            PriceBand(
                title: "Normal",
                rangeText: "5-10 ct",
                count: prices.filter { $0.marketprice >= 5 && $0.marketprice < 10 }.count,
                tint: Color(red: 0.94, green: 0.55, blue: 0.26)
            ),
            PriceBand(
                title: "Moderate",
                rangeText: "10-15 ct",
                count: prices.filter { $0.marketprice >= 10 && $0.marketprice < 15 }.count,
                tint: Color(red: 0.90, green: 0.42, blue: 0.24)
            ),
            PriceBand(
                title: "Peak",
                rangeText: "> 15 ct",
                count: prices.filter { $0.marketprice >= 15 }.count,
                tint: Color(red: 0.82, green: 0.28, blue: 0.20)
            ),
        ]
    }

    var nowContextText: String {
        guard let currentPrice, let averagePrice else {
            return "Waiting for price data."
        }

        if currentPrice.marketprice < 0 {
            return "Prices are negative right now."
        }

        if currentPrice.marketprice < averagePrice {
            return "Current price is below the upcoming average."
        }

        return "Current price is above the upcoming average."
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

private struct InsightMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        InsightsCard(tint: tint) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.headline)
                        .monospacedDigit()
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
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

private struct PriceBandRow: View {
    let band: PriceBand
    let totalCount: Int

    private var progress: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(band.count) / CGFloat(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(band.tint)
                    .frame(width: 8, height: 8)

                Text(band.title)
                    .font(.caption.weight(.semibold))

                Text(band.rangeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(band.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.12))

                    Capsule()
                        .fill(band.tint)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
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

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]
    }

    var body: some View {
        NavigationStack {
            Group {
                if prices.isEmpty {
                    DataDownloadAndError()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            InsightsCard(tint: insightsAccent) {
                                HStack(spacing: 5) {
                                    Image(systemName: "bolt.fill")
                                        .foregroundStyle(insightsAccent)
                                    
                                    Text(model.nowContextText)
                                        .font(.subheadline)
                                }
                            }

                            LazyVGrid(columns: metricColumns, spacing: 10) {
                                InsightMetricCard(
                                    title: "Current",
                                    value: priceText(model.currentPrice?.marketprice),
                                    subtitle: model.currentPrice.map { timeRangeText(from: $0.startTime, to: $0.endTime) },
                                    systemImage: "clock",
                                    tint: AppTheme.accent
                                )

                                InsightMetricCard(
                                    title: "Average",
                                    value: priceText(model.averagePrice),
                                    subtitle: "",
                                    systemImage: "chart.line.uptrend.xyaxis",
                                    tint: Color.secondary
                                )

                                InsightMetricCard(
                                    title: "Lowest",
                                    value: priceText(model.minPrice?.marketprice),
                                    subtitle: model.minPrice.map { timeRangeText(from: $0.startTime, to: $0.endTime) },
                                    systemImage: "arrow.down.circle.fill",
                                    tint: AppTheme.success
                                )

                                InsightMetricCard(
                                    title: "Highest",
                                    value: priceText(model.maxPrice?.marketprice),
                                    subtitle: model.maxPrice.map { timeRangeText(from: $0.startTime, to: $0.endTime) },
                                    systemImage: "arrow.up.circle.fill",
                                    tint: AppTheme.error
                                )

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

                            InsightsCard(tint: AppTheme.accent) {
                                InsightsSectionTitle(
                                    title: "Distribution",
                                    systemImage: "chart.bar.fill",
                                    tint: AppTheme.accent
                                )

                                ForEach(model.priceBands) { band in
                                    PriceBandRow(band: band, totalCount: prices.count)
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
